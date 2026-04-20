create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new."updatedAt" = now();
  return new;
end;
$$;

create table if not exists public.universities (
  id text primary key,
  name text not null,
  country text not null,
  city text not null,
  "websiteURL" text not null,
  "rankingBucket" text,
  type text not null,
  region text not null default '',
  "featuredForBangladesh" boolean not null default true
);

create table if not exists public.programs (
  id text primary key,
  "universityID" text not null references public.universities (id) on delete cascade,
  "universityName" text not null,
  name text not null,
  "degreeLevel" text not null,
  "subjectArea" text not null,
  "durationMonths" integer not null,
  "tuitionUSD" integer not null,
  "applicationFeeUSD" integer not null,
  "officialURL" text not null,
  summary text not null,
  "intakeTerms" jsonb not null default '[]'::jsonb,
  "scholarshipAvailable" boolean not null default false,
  "applicationPortal" text not null default 'University Portal',
  "studyMode" text not null default 'Full Time',
  "estimatedLivingCostUSD" integer not null default 0,
  "totalCostOfAttendanceUSD" integer not null default 0,
  "dataFreshness" text not null default 'Curated',
  "lastUpdatedAt" timestamptz not null default now(),
  "bangladeshFitNote" text not null default ''
);

create table if not exists public.program_requirements (
  id text primary key,
  "programID" text not null references public.programs (id) on delete cascade,
  "minGPAValue" double precision not null,
  "minGPAScale" double precision not null,
  "minSecondaryPercent" double precision,
  "ieltsMin" double precision,
  "toeflMin" double precision,
  "duolingoMin" double precision,
  "satMin" integer,
  "greRequired" boolean not null default false,
  "gmatRequired" boolean not null default false,
  "sopRequired" boolean not null default true,
  "cvRequired" boolean not null default true,
  "lorCount" integer not null default 0,
  "transcriptRequired" boolean not null default true,
  "passportRequired" boolean not null default true,
  "financialProofRequired" boolean not null default true,
  "portfolioRequired" boolean not null default false,
  notes text not null default ''
);

create table if not exists public.program_deadlines (
  id text primary key,
  "programID" text not null references public.programs (id) on delete cascade,
  "intakeTerm" text not null,
  "applicationDeadline" timestamptz not null,
  "scholarshipDeadline" timestamptz,
  "depositDeadline" timestamptz,
  "interviewWindowStart" timestamptz,
  "visaPrepStart" timestamptz,
  "decisionExpected" timestamptz,
  notes text not null default ''
);

create table if not exists public.scholarships (
  id text primary key,
  name text not null,
  sponsor text not null,
  "destinationCountries" jsonb not null default '[]'::jsonb,
  "eligibleNationalities" jsonb not null default '[]'::jsonb,
  "eligibleSubjects" jsonb not null default '[]'::jsonb,
  "eligibleDegreeLevels" jsonb not null default '[]'::jsonb,
  "minGPAValue" double precision,
  "minSecondaryPercent" double precision,
  "coverageType" text not null,
  "maxAmountUSD" integer,
  "officialURL" text not null,
  summary text not null,
  deadline timestamptz not null,
  "needBased" boolean not null default false,
  "meritBased" boolean not null default true,
  "lastUpdatedAt" timestamptz not null default now(),
  "essayPromptHint" text not null default ''
);

create table if not exists public.peer_profiles (
  id text primary key,
  "displayName" text not null,
  nationality text not null,
  "currentCountry" text not null,
  role text not null,
  "verificationStatus" text not null default 'Unverified',
  "currentUniversity" text not null,
  "currentProgram" text not null,
  bio text not null default '',
  "subjectAreas" jsonb not null default '[]'::jsonb,
  "targetCountries" jsonb not null default '[]'::jsonb,
  "reputationScore" integer not null default 0,
  outcomes jsonb not null default '[]'::jsonb
);

create table if not exists public.peer_posts (
  id text primary key,
  "authorID" text not null,
  title text not null,
  body text not null,
  kind text not null,
  country text not null,
  "subjectArea" text not null,
  "degreeLevel" text not null,
  "programID" text,
  "scholarshipID" text,
  tags jsonb not null default '[]'::jsonb,
  "moderationStatus" text not null default 'Under Review',
  "createdAt" timestamptz not null default now(),
  "upvoteCount" integer not null default 0
);

create table if not exists public.peer_replies (
  id text primary key,
  "postID" text not null references public.peer_posts (id) on delete cascade,
  "authorID" text not null,
  body text not null,
  "createdAt" timestamptz not null default now(),
  "moderationStatus" text not null default 'Under Review',
  "isAcceptedAnswer" boolean not null default false
);

create table if not exists public.peer_artifacts (
  id text primary key,
  "authorID" text not null,
  "programID" text,
  title text not null,
  summary text not null,
  kind text not null,
  country text not null,
  "subjectArea" text not null,
  "degreeLevel" text not null,
  "verificationStatus" text not null default 'Unverified',
  "moderationStatus" text not null default 'Under Review',
  "createdAt" timestamptz not null default now(),
  "bulletHighlights" jsonb not null default '[]'::jsonb
);

create table if not exists public.user_profiles (
  id text primary key,
  email text not null unique,
  "displayName" text not null,
  "avatarURL" text,
  role text not null default 'student',
  "verificationStatus" text not null default 'Unverified',
  "googleProvider" text not null default 'google',
  "createdAt" timestamptz not null default now(),
  "updatedAt" timestamptz not null default now()
);

create table if not exists public.user_workspaces (
  "user_id" text primary key references public.user_profiles (id) on delete cascade,
  workspace jsonb not null default '{}'::jsonb,
  "updatedAt" timestamptz not null default now()
);

create table if not exists public.community_reports (
  id text primary key,
  "userID" text not null references public.user_profiles (id) on delete cascade,
  "postID" text not null references public.peer_posts (id) on delete cascade,
  reason text not null,
  "createdAt" timestamptz not null default now(),
  status text not null default 'Under Review'
);

create table if not exists public.verification_requests (
  id text primary key default gen_random_uuid()::text,
  "user_id" text not null references public.user_profiles (id) on delete cascade,
  "userEmail" text,
  note text not null,
  "createdAt" timestamptz not null default now(),
  status text not null default 'Under Review'
);

create table if not exists public.admin_audit_log (
  id uuid primary key default gen_random_uuid(),
  "actorID" text not null,
  action text not null,
  payload jsonb not null default '{}'::jsonb,
  "createdAt" timestamptz not null default now()
);

create index if not exists programs_university_idx on public.programs ("universityID");
create index if not exists peer_posts_author_idx on public.peer_posts ("authorID");
create index if not exists peer_posts_program_idx on public.peer_posts ("programID");
create index if not exists peer_replies_post_idx on public.peer_replies ("postID");
create index if not exists peer_artifacts_author_idx on public.peer_artifacts ("authorID");
create index if not exists community_reports_post_idx on public.community_reports ("postID");
create index if not exists verification_requests_user_idx on public.verification_requests ("user_id");

create trigger user_profiles_updated_at
before update on public.user_profiles
for each row
execute function public.set_updated_at();

create trigger user_workspaces_updated_at
before update on public.user_workspaces
for each row
execute function public.set_updated_at();

create or replace function public.is_staff()
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.user_profiles
    where id = auth.uid()::text
      and role = 'staff'
  );
$$;

alter table public.universities enable row level security;
alter table public.programs enable row level security;
alter table public.program_requirements enable row level security;
alter table public.program_deadlines enable row level security;
alter table public.scholarships enable row level security;
alter table public.peer_profiles enable row level security;
alter table public.peer_posts enable row level security;
alter table public.peer_replies enable row level security;
alter table public.peer_artifacts enable row level security;
alter table public.user_profiles enable row level security;
alter table public.user_workspaces enable row level security;
alter table public.community_reports enable row level security;
alter table public.verification_requests enable row level security;
alter table public.admin_audit_log enable row level security;

create policy "public_catalog_read_universities"
on public.universities for select
using (true);

create policy "public_catalog_read_programs"
on public.programs for select
using (true);

create policy "public_catalog_read_requirements"
on public.program_requirements for select
using (true);

create policy "public_catalog_read_deadlines"
on public.program_deadlines for select
using (true);

create policy "public_catalog_read_scholarships"
on public.scholarships for select
using (true);

create policy "public_peer_profiles_read"
on public.peer_profiles for select
using (true);

create policy "public_peer_posts_read"
on public.peer_posts for select
using ("moderationStatus" <> 'Limited');

create policy "public_peer_replies_read"
on public.peer_replies for select
using ("moderationStatus" <> 'Limited');

create policy "public_peer_artifacts_read"
on public.peer_artifacts for select
using ("moderationStatus" <> 'Limited');

create policy "own_user_profile_select"
on public.user_profiles for select
using (id = auth.uid()::text or public.is_staff());

create policy "own_user_profile_insert"
on public.user_profiles for insert
with check (id = auth.uid()::text);

create policy "own_user_profile_update"
on public.user_profiles for update
using (id = auth.uid()::text or public.is_staff())
with check (id = auth.uid()::text or public.is_staff());

create policy "own_workspace_select"
on public.user_workspaces for select
using ("user_id" = auth.uid()::text or public.is_staff());

create policy "own_workspace_insert"
on public.user_workspaces for insert
with check ("user_id" = auth.uid()::text);

create policy "own_workspace_update"
on public.user_workspaces for update
using ("user_id" = auth.uid()::text or public.is_staff())
with check ("user_id" = auth.uid()::text or public.is_staff());

create policy "authenticated_post_insert"
on public.peer_posts for insert
with check (auth.uid()::text = "authorID");

create policy "authenticated_reply_insert"
on public.peer_replies for insert
with check (auth.uid()::text = "authorID");

create policy "verified_artifact_insert"
on public.peer_artifacts for insert
with check (
  auth.uid()::text = "authorID"
  and exists (
    select 1
    from public.user_profiles
    where id = auth.uid()::text
      and "verificationStatus" <> 'Unverified'
  )
);

create policy "author_update_own_posts"
on public.peer_posts for update
using (auth.uid()::text = "authorID" or public.is_staff())
with check (auth.uid()::text = "authorID" or public.is_staff());

create policy "author_update_own_replies"
on public.peer_replies for update
using (auth.uid()::text = "authorID" or public.is_staff())
with check (auth.uid()::text = "authorID" or public.is_staff());

create policy "author_update_own_artifacts"
on public.peer_artifacts for update
using (auth.uid()::text = "authorID" or public.is_staff())
with check (auth.uid()::text = "authorID" or public.is_staff());

create policy "report_insert"
on public.community_reports for insert
with check ("userID" = auth.uid()::text);

create policy "report_select_staff"
on public.community_reports for select
using (public.is_staff());

create policy "report_update_staff"
on public.community_reports for update
using (public.is_staff())
with check (public.is_staff());

create policy "verification_insert"
on public.verification_requests for insert
with check ("user_id" = auth.uid()::text);

create policy "verification_select_own_or_staff"
on public.verification_requests for select
using ("user_id" = auth.uid()::text or public.is_staff());

create policy "verification_update_staff"
on public.verification_requests for update
using (public.is_staff())
with check (public.is_staff());

create policy "admin_audit_staff_only"
on public.admin_audit_log for all
using (public.is_staff())
with check (public.is_staff());

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('avatars', 'avatars', true, 1048576, array['image/jpeg', 'image/png', 'image/webp']),
  ('peer-artifacts', 'peer-artifacts', false, 5242880, array['application/pdf', 'image/jpeg', 'image/png', 'image/webp']),
  ('verification-evidence', 'verification-evidence', false, 2097152, array['application/pdf', 'image/jpeg', 'image/png'])
on conflict (id) do nothing;

create policy "avatars_public_read"
on storage.objects for select
using (bucket_id = 'avatars');

create policy "avatars_authenticated_insert"
on storage.objects for insert
with check (
  bucket_id = 'avatars'
  and auth.role() = 'authenticated'
);

create policy "avatars_owner_update"
on storage.objects for update
using (bucket_id = 'avatars' and auth.role() = 'authenticated')
with check (bucket_id = 'avatars' and auth.role() = 'authenticated');

create policy "peer_artifacts_authenticated_read"
on storage.objects for select
using (
  bucket_id = 'peer-artifacts'
  and auth.role() = 'authenticated'
);

create policy "peer_artifacts_verified_insert"
on storage.objects for insert
with check (
  bucket_id = 'peer-artifacts'
  and exists (
    select 1
    from public.user_profiles
    where id = auth.uid()::text
      and "verificationStatus" <> 'Unverified'
  )
);

create policy "verification_evidence_owner_or_staff_read"
on storage.objects for select
using (
  bucket_id = 'verification-evidence'
  and (auth.role() = 'authenticated' or public.is_staff())
);

create policy "verification_evidence_authenticated_insert"
on storage.objects for insert
with check (
  bucket_id = 'verification-evidence'
  and auth.role() = 'authenticated'
);
