create extension if not exists pgcrypto;
create extension if not exists pgmq;

create table if not exists captures (
    id uuid primary key default gen_random_uuid(),
    input_type text not null check (input_type in ('url', 'screenshot')),
    status text not null check (status in ('queued', 'processing', 'needs_review', 'partially_resolved', 'completed', 'failed')) default 'queued',
    source_url text,
    source_domain text,
    source_app text,
    title text not null,
    excerpt text,
    raw_text text,
    image_file_name text,
    captured_lat double precision,
    captured_lng double precision,
    error_message text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists place_drafts (
    id uuid primary key default gen_random_uuid(),
    capture_id uuid not null references captures(id) on delete cascade,
    title text not null,
    category text not null default 'other',
    notes text,
    address_line text,
    city text,
    neighborhood text,
    confidence double precision not null default 0,
    status text not null check (status in ('auto_activated', 'needs_review', 'duplicate_candidate', 'rejected')) default 'needs_review',
    source_excerpt text,
    duplicate_of_place_id uuid,
    created_at timestamptz not null default now()
);

create table if not exists places (
    id uuid primary key default gen_random_uuid(),
    source_capture_id uuid not null references captures(id) on delete cascade,
    title text not null,
    category text not null,
    address_line text not null,
    city text,
    neighborhood text,
    notes text,
    confidence double precision not null default 0,
    lat double precision,
    lng double precision,
    source_domain text,
    created_at timestamptz not null default now(),
    visited_at timestamptz,
    archived_at timestamptz
);

select pgmq.create('capture_enrichment_queue');

create or replace function enqueue_capture_for_enrichment()
returns trigger
language plpgsql
as $$
begin
    perform pgmq.send(
        'capture_enrichment_queue',
        jsonb_build_object(
            'capture_id', new.id,
            'source_url', new.source_url,
            'input_type', new.input_type
        )
    );
    return new;
end;
$$;

drop trigger if exists captures_enqueue_trigger on captures;
create trigger captures_enqueue_trigger
after insert on captures
for each row
execute function enqueue_capture_for_enrichment();
