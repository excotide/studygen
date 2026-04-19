-- StudyGen schema for Supabase Auth (UUID user ids + RLS)

create table if not exists public.quizzes (
  id bigserial primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  title varchar(255) not null,
  summary text not null,
  extraction_mode varchar(50) not null default 'parser',
  last_score int null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.questions (
  id bigserial primary key,
  quiz_id bigint not null references public.quizzes(id) on delete cascade,
  question text not null,
  options jsonb not null,
  correct_answer smallint not null,
  created_at timestamptz not null default now()
);

create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists quizzes_set_updated_at on public.quizzes;
create trigger quizzes_set_updated_at
before update on public.quizzes
for each row
execute function public.set_updated_at();

create index if not exists idx_quizzes_user_id_created_at
on public.quizzes(user_id, created_at desc);

create index if not exists idx_questions_quiz_id
on public.questions(quiz_id);

alter table public.quizzes enable row level security;
alter table public.questions enable row level security;

drop policy if exists quizzes_select_own on public.quizzes;
create policy quizzes_select_own
on public.quizzes for select
using (auth.uid() = user_id);

drop policy if exists quizzes_insert_own on public.quizzes;
create policy quizzes_insert_own
on public.quizzes for insert
with check (auth.uid() = user_id);

drop policy if exists quizzes_update_own on public.quizzes;
create policy quizzes_update_own
on public.quizzes for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists quizzes_delete_own on public.quizzes;
create policy quizzes_delete_own
on public.quizzes for delete
using (auth.uid() = user_id);

drop policy if exists questions_select_own on public.questions;
create policy questions_select_own
on public.questions for select
using (
  exists (
    select 1 from public.quizzes q
    where q.id = questions.quiz_id and q.user_id = auth.uid()
  )
);

drop policy if exists questions_insert_own on public.questions;
create policy questions_insert_own
on public.questions for insert
with check (
  exists (
    select 1 from public.quizzes q
    where q.id = questions.quiz_id and q.user_id = auth.uid()
  )
);

drop policy if exists questions_update_own on public.questions;
create policy questions_update_own
on public.questions for update
using (
  exists (
    select 1 from public.quizzes q
    where q.id = questions.quiz_id and q.user_id = auth.uid()
  )
)
with check (
  exists (
    select 1 from public.quizzes q
    where q.id = questions.quiz_id and q.user_id = auth.uid()
  )
);

drop policy if exists questions_delete_own on public.questions;
create policy questions_delete_own
on public.questions for delete
using (
  exists (
    select 1 from public.quizzes q
    where q.id = questions.quiz_id and q.user_id = auth.uid()
  )
);
