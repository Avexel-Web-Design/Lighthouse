SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: active_storage_attachments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_attachments (
    id bigint NOT NULL,
    blob_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    name character varying NOT NULL,
    record_id bigint NOT NULL,
    record_type character varying NOT NULL
);


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_attachments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_attachments_id_seq OWNED BY public.active_storage_attachments.id;


--
-- Name: active_storage_blobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_blobs (
    id bigint NOT NULL,
    byte_size bigint NOT NULL,
    checksum character varying,
    content_type character varying,
    created_at timestamp(6) without time zone NOT NULL,
    filename character varying NOT NULL,
    key character varying NOT NULL,
    metadata text,
    service_name character varying NOT NULL
);


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_blobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_blobs_id_seq OWNED BY public.active_storage_blobs.id;


--
-- Name: active_storage_variant_records; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_variant_records (
    id bigint NOT NULL,
    blob_id bigint NOT NULL,
    variation_digest character varying NOT NULL
);


--
-- Name: active_storage_variant_records_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_variant_records_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_variant_records_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_variant_records_id_seq OWNED BY public.active_storage_variant_records.id;


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: data_conflicts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.data_conflicts (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    event_id bigint NOT NULL,
    field_name character varying NOT NULL,
    frc_team_id bigint NOT NULL,
    match_id bigint NOT NULL,
    resolution_value character varying,
    resolved boolean DEFAULT false NOT NULL,
    resolved_by_id bigint,
    updated_at timestamp(6) without time zone NOT NULL,
    "values" jsonb DEFAULT '{}'::jsonb NOT NULL
);


--
-- Name: data_conflicts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.data_conflicts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: data_conflicts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.data_conflicts_id_seq OWNED BY public.data_conflicts.id;


--
-- Name: event_teams; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.event_teams (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    event_id bigint NOT NULL,
    frc_team_id bigint NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: event_teams_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.event_teams_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: event_teams_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.event_teams_id_seq OWNED BY public.event_teams.id;


--
-- Name: events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.events (
    id bigint NOT NULL,
    city character varying,
    country character varying,
    created_at timestamp(6) without time zone NOT NULL,
    end_date date,
    event_type integer,
    name character varying,
    start_date date,
    state_prov character varying,
    tba_key character varying,
    updated_at timestamp(6) without time zone NOT NULL,
    week integer,
    year integer
);


--
-- Name: events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.events_id_seq OWNED BY public.events.id;


--
-- Name: frc_teams; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.frc_teams (
    id bigint NOT NULL,
    city character varying,
    country character varying,
    created_at timestamp(6) without time zone NOT NULL,
    nickname character varying,
    rookie_year integer,
    state_prov character varying,
    team_number integer,
    updated_at timestamp(6) without time zone NOT NULL,
    website character varying
);


--
-- Name: frc_teams_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.frc_teams_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: frc_teams_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.frc_teams_id_seq OWNED BY public.frc_teams.id;


--
-- Name: game_configs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.game_configs (
    id bigint NOT NULL,
    active boolean DEFAULT false NOT NULL,
    config jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    game_name character varying NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    year integer NOT NULL
);


--
-- Name: game_configs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.game_configs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: game_configs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.game_configs_id_seq OWNED BY public.game_configs.id;


--
-- Name: match_alliances; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.match_alliances (
    id bigint NOT NULL,
    alliance_color character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    frc_team_id bigint NOT NULL,
    match_id bigint NOT NULL,
    station integer NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: match_alliances_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.match_alliances_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: match_alliances_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.match_alliances_id_seq OWNED BY public.match_alliances.id;


--
-- Name: matches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.matches (
    id bigint NOT NULL,
    comp_level character varying,
    created_at timestamp(6) without time zone NOT NULL,
    event_id bigint NOT NULL,
    match_number integer,
    scheduled_time timestamp(6) without time zone,
    set_number integer,
    tba_key character varying,
    updated_at timestamp(6) without time zone NOT NULL,
    red_score integer,
    blue_score integer,
    actual_time timestamp(6) without time zone,
    predicted_time timestamp(6) without time zone,
    post_result_time timestamp(6) without time zone,
    videos jsonb DEFAULT '[]'::jsonb NOT NULL
);


--
-- Name: matches_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.matches_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: matches_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.matches_id_seq OWNED BY public.matches.id;


--
-- Name: pick_lists; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pick_lists (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    entries jsonb,
    event_id bigint NOT NULL,
    name character varying,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id bigint NOT NULL
);


--
-- Name: pick_lists_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.pick_lists_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pick_lists_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.pick_lists_id_seq OWNED BY public.pick_lists.id;


--
-- Name: pit_scouting_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pit_scouting_entries (
    id bigint NOT NULL,
    client_uuid character varying,
    created_at timestamp(6) without time zone NOT NULL,
    data jsonb DEFAULT '{}'::jsonb NOT NULL,
    event_id bigint NOT NULL,
    frc_team_id bigint NOT NULL,
    notes text,
    status integer DEFAULT 0 NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id bigint NOT NULL
);


--
-- Name: pit_scouting_entries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.pit_scouting_entries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pit_scouting_entries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.pit_scouting_entries_id_seq OWNED BY public.pit_scouting_entries.id;


--
-- Name: predictions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.predictions (
    id bigint NOT NULL,
    actual_blue_score integer,
    actual_red_score integer,
    blue_score double precision,
    blue_win_probability double precision,
    created_at timestamp(6) without time zone NOT NULL,
    details jsonb DEFAULT '{}'::jsonb NOT NULL,
    event_id bigint NOT NULL,
    match_id bigint NOT NULL,
    red_score double precision,
    red_win_probability double precision,
    source character varying,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: predictions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.predictions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: predictions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.predictions_id_seq OWNED BY public.predictions.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: scouting_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.scouting_assignments (
    id bigint NOT NULL,
    event_id bigint NOT NULL,
    user_id bigint NOT NULL,
    match_id bigint NOT NULL,
    frc_team_id bigint,
    alliance_color character varying,
    station integer,
    notes text,
    notified_5_at timestamp(6) without time zone,
    notified_2_at timestamp(6) without time zone,
    notified_1_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: scouting_assignments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.scouting_assignments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: scouting_assignments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.scouting_assignments_id_seq OWNED BY public.scouting_assignments.id;


--
-- Name: scouting_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.scouting_entries (
    id bigint NOT NULL,
    client_uuid character varying,
    created_at timestamp(6) without time zone NOT NULL,
    data jsonb DEFAULT '{}'::jsonb NOT NULL,
    event_id bigint NOT NULL,
    frc_team_id bigint NOT NULL,
    match_id bigint,
    notes text,
    photo_url character varying,
    status integer DEFAULT 0 NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id bigint NOT NULL,
    scouting_mode integer DEFAULT 0 NOT NULL,
    video_key character varying,
    video_type character varying
);


--
-- Name: scouting_entries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.scouting_entries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: scouting_entries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.scouting_entries_id_seq OWNED BY public.scouting_entries.id;


--
-- Name: simulation_results; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.simulation_results (
    id bigint NOT NULL,
    blue_team_ids jsonb DEFAULT '[]'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    event_id bigint NOT NULL,
    iterations integer DEFAULT 1000,
    name character varying,
    red_team_ids jsonb DEFAULT '[]'::jsonb NOT NULL,
    results jsonb DEFAULT '{}'::jsonb NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id bigint NOT NULL
);


--
-- Name: simulation_results_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.simulation_results_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: simulation_results_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.simulation_results_id_seq OWNED BY public.simulation_results.id;


--
-- Name: statbotics_caches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.statbotics_caches (
    id bigint NOT NULL,
    frc_team_id bigint NOT NULL,
    event_id bigint NOT NULL,
    epa_mean double precision,
    epa_sd double precision,
    wins integer DEFAULT 0,
    losses integer DEFAULT 0,
    ties integer DEFAULT 0,
    qual_wins integer DEFAULT 0,
    qual_losses integer DEFAULT 0,
    qual_rank integer,
    qual_num_teams integer,
    winrate double precision,
    data jsonb DEFAULT '{}'::jsonb NOT NULL,
    last_synced_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: statbotics_caches_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.statbotics_caches_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: statbotics_caches_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.statbotics_caches_id_seq OWNED BY public.statbotics_caches.id;


--
-- Name: team_event_summaries; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW public.team_event_summaries AS
 SELECT event_id,
    frc_team_id,
    count(*) AS matches_scouted,
    avg(((COALESCE(((data ->> 'auton_fuel_made'::text))::numeric, (0)::numeric) + COALESCE(((data ->> 'teleop_fuel_made'::text))::numeric, (0)::numeric)) + COALESCE(((data ->> 'endgame_fuel_made'::text))::numeric, (0)::numeric))) AS avg_fuel_made,
    avg(((COALESCE(((data ->> 'auton_fuel_missed'::text))::numeric, (0)::numeric) + COALESCE(((data ->> 'teleop_fuel_missed'::text))::numeric, (0)::numeric)) + COALESCE(((data ->> 'endgame_fuel_missed'::text))::numeric, (0)::numeric))) AS avg_fuel_missed,
        CASE
            WHEN (sum((((((COALESCE(((data ->> 'auton_fuel_made'::text))::numeric, (0)::numeric) + COALESCE(((data ->> 'teleop_fuel_made'::text))::numeric, (0)::numeric)) + COALESCE(((data ->> 'endgame_fuel_made'::text))::numeric, (0)::numeric)) + COALESCE(((data ->> 'auton_fuel_missed'::text))::numeric, (0)::numeric)) + COALESCE(((data ->> 'teleop_fuel_missed'::text))::numeric, (0)::numeric)) + COALESCE(((data ->> 'endgame_fuel_missed'::text))::numeric, (0)::numeric))) > (0)::numeric) THEN round(((sum(((COALESCE(((data ->> 'auton_fuel_made'::text))::numeric, (0)::numeric) + COALESCE(((data ->> 'teleop_fuel_made'::text))::numeric, (0)::numeric)) + COALESCE(((data ->> 'endgame_fuel_made'::text))::numeric, (0)::numeric))) * 100.0) / NULLIF(sum((((((COALESCE(((data ->> 'auton_fuel_made'::text))::numeric, (0)::numeric) + COALESCE(((data ->> 'teleop_fuel_made'::text))::numeric, (0)::numeric)) + COALESCE(((data ->> 'endgame_fuel_made'::text))::numeric, (0)::numeric)) + COALESCE(((data ->> 'auton_fuel_missed'::text))::numeric, (0)::numeric)) + COALESCE(((data ->> 'teleop_fuel_missed'::text))::numeric, (0)::numeric)) + COALESCE(((data ->> 'endgame_fuel_missed'::text))::numeric, (0)::numeric))), (0)::numeric)), 1)
            ELSE (0)::numeric
        END AS fuel_accuracy_pct,
    avg((
        CASE
            WHEN ((data ->> 'auton_climb'::text))::boolean THEN 15
            ELSE 0
        END +
        CASE (data ->> 'endgame_climb'::text)
            WHEN 'L3'::text THEN 30
            WHEN 'L2'::text THEN 20
            WHEN 'L1'::text THEN 10
            ELSE 0
        END)) AS avg_climb_points,
    avg(((((COALESCE(((data ->> 'auton_fuel_made'::text))::numeric, (0)::numeric) + COALESCE(((data ->> 'teleop_fuel_made'::text))::numeric, (0)::numeric)) + COALESCE(((data ->> 'endgame_fuel_made'::text))::numeric, (0)::numeric)) + (
        CASE
            WHEN ((data ->> 'auton_climb'::text))::boolean THEN 15
            ELSE 0
        END)::numeric) + (
        CASE (data ->> 'endgame_climb'::text)
            WHEN 'L3'::text THEN 30
            WHEN 'L2'::text THEN 20
            WHEN 'L1'::text THEN 10
            ELSE 0
        END)::numeric)) AS avg_total_points,
    stddev_samp(((((COALESCE(((data ->> 'auton_fuel_made'::text))::numeric, (0)::numeric) + COALESCE(((data ->> 'teleop_fuel_made'::text))::numeric, (0)::numeric)) + COALESCE(((data ->> 'endgame_fuel_made'::text))::numeric, (0)::numeric)) + (
        CASE
            WHEN ((data ->> 'auton_climb'::text))::boolean THEN 15
            ELSE 0
        END)::numeric) + (
        CASE (data ->> 'endgame_climb'::text)
            WHEN 'L3'::text THEN 30
            WHEN 'L2'::text THEN 20
            WHEN 'L1'::text THEN 10
            ELSE 0
        END)::numeric)) AS stddev_total_points,
    avg((COALESCE(((data ->> 'auton_fuel_made'::text))::numeric, (0)::numeric) + (
        CASE
            WHEN ((data ->> 'auton_climb'::text))::boolean THEN 15
            ELSE 0
        END)::numeric)) AS avg_auton_points,
    avg(NULLIF(COALESCE(((data ->> 'defense_rating'::text))::numeric, (0)::numeric), (0)::numeric)) AS avg_defense_rating,
    max(updated_at) AS last_updated
   FROM public.scouting_entries
   WHERE (status = ANY (ARRAY[0, 3]))
  GROUP BY event_id, frc_team_id
  WITH NO DATA;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    api_token character varying,
    avatar_url character varying,
    created_at timestamp(6) without time zone NOT NULL,
    email character varying DEFAULT ''::character varying NOT NULL,
    encrypted_password character varying DEFAULT ''::character varying NOT NULL,
    first_name character varying,
    last_name character varying,
    remember_created_at timestamp(6) without time zone,
    reset_password_sent_at timestamp(6) without time zone,
    reset_password_token character varying,
    team_number integer,
    updated_at timestamp(6) without time zone NOT NULL,
    role integer DEFAULT 0 NOT NULL,
    username character varying NOT NULL
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: web_push_subscriptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.web_push_subscriptions (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    endpoint character varying NOT NULL,
    p256dh character varying NOT NULL,
    auth character varying NOT NULL,
    user_agent character varying,
    last_seen_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: web_push_subscriptions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.web_push_subscriptions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: web_push_subscriptions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.web_push_subscriptions_id_seq OWNED BY public.web_push_subscriptions.id;


--
-- Name: active_storage_attachments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments ALTER COLUMN id SET DEFAULT nextval('public.active_storage_attachments_id_seq'::regclass);


--
-- Name: active_storage_blobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs ALTER COLUMN id SET DEFAULT nextval('public.active_storage_blobs_id_seq'::regclass);


--
-- Name: active_storage_variant_records id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records ALTER COLUMN id SET DEFAULT nextval('public.active_storage_variant_records_id_seq'::regclass);


--
-- Name: data_conflicts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.data_conflicts ALTER COLUMN id SET DEFAULT nextval('public.data_conflicts_id_seq'::regclass);


--
-- Name: event_teams id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.event_teams ALTER COLUMN id SET DEFAULT nextval('public.event_teams_id_seq'::regclass);


--
-- Name: events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.events ALTER COLUMN id SET DEFAULT nextval('public.events_id_seq'::regclass);


--
-- Name: frc_teams id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.frc_teams ALTER COLUMN id SET DEFAULT nextval('public.frc_teams_id_seq'::regclass);


--
-- Name: game_configs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.game_configs ALTER COLUMN id SET DEFAULT nextval('public.game_configs_id_seq'::regclass);


--
-- Name: match_alliances id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_alliances ALTER COLUMN id SET DEFAULT nextval('public.match_alliances_id_seq'::regclass);


--
-- Name: matches id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.matches ALTER COLUMN id SET DEFAULT nextval('public.matches_id_seq'::regclass);


--
-- Name: pick_lists id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pick_lists ALTER COLUMN id SET DEFAULT nextval('public.pick_lists_id_seq'::regclass);


--
-- Name: pit_scouting_entries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pit_scouting_entries ALTER COLUMN id SET DEFAULT nextval('public.pit_scouting_entries_id_seq'::regclass);


--
-- Name: predictions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.predictions ALTER COLUMN id SET DEFAULT nextval('public.predictions_id_seq'::regclass);


--
-- Name: scouting_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scouting_assignments ALTER COLUMN id SET DEFAULT nextval('public.scouting_assignments_id_seq'::regclass);


--
-- Name: scouting_entries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scouting_entries ALTER COLUMN id SET DEFAULT nextval('public.scouting_entries_id_seq'::regclass);


--
-- Name: simulation_results id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.simulation_results ALTER COLUMN id SET DEFAULT nextval('public.simulation_results_id_seq'::regclass);


--
-- Name: statbotics_caches id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.statbotics_caches ALTER COLUMN id SET DEFAULT nextval('public.statbotics_caches_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: web_push_subscriptions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.web_push_subscriptions ALTER COLUMN id SET DEFAULT nextval('public.web_push_subscriptions_id_seq'::regclass);


--
-- Name: active_storage_attachments active_storage_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT active_storage_attachments_pkey PRIMARY KEY (id);


--
-- Name: active_storage_blobs active_storage_blobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs
    ADD CONSTRAINT active_storage_blobs_pkey PRIMARY KEY (id);


--
-- Name: active_storage_variant_records active_storage_variant_records_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT active_storage_variant_records_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: data_conflicts data_conflicts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.data_conflicts
    ADD CONSTRAINT data_conflicts_pkey PRIMARY KEY (id);


--
-- Name: event_teams event_teams_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.event_teams
    ADD CONSTRAINT event_teams_pkey PRIMARY KEY (id);


--
-- Name: events events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT events_pkey PRIMARY KEY (id);


--
-- Name: frc_teams frc_teams_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.frc_teams
    ADD CONSTRAINT frc_teams_pkey PRIMARY KEY (id);


--
-- Name: game_configs game_configs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.game_configs
    ADD CONSTRAINT game_configs_pkey PRIMARY KEY (id);


--
-- Name: match_alliances match_alliances_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_alliances
    ADD CONSTRAINT match_alliances_pkey PRIMARY KEY (id);


--
-- Name: matches matches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.matches
    ADD CONSTRAINT matches_pkey PRIMARY KEY (id);


--
-- Name: pick_lists pick_lists_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pick_lists
    ADD CONSTRAINT pick_lists_pkey PRIMARY KEY (id);


--
-- Name: pit_scouting_entries pit_scouting_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pit_scouting_entries
    ADD CONSTRAINT pit_scouting_entries_pkey PRIMARY KEY (id);


--
-- Name: predictions predictions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.predictions
    ADD CONSTRAINT predictions_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: scouting_assignments scouting_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scouting_assignments
    ADD CONSTRAINT scouting_assignments_pkey PRIMARY KEY (id);


--
-- Name: scouting_entries scouting_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scouting_entries
    ADD CONSTRAINT scouting_entries_pkey PRIMARY KEY (id);


--
-- Name: simulation_results simulation_results_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.simulation_results
    ADD CONSTRAINT simulation_results_pkey PRIMARY KEY (id);


--
-- Name: statbotics_caches statbotics_caches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.statbotics_caches
    ADD CONSTRAINT statbotics_caches_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: web_push_subscriptions web_push_subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.web_push_subscriptions
    ADD CONSTRAINT web_push_subscriptions_pkey PRIMARY KEY (id);


--
-- Name: idx_data_conflicts_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_data_conflicts_unique ON public.data_conflicts USING btree (event_id, frc_team_id, match_id, field_name);


--
-- Name: idx_match_alliances_unique_station; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_match_alliances_unique_station ON public.match_alliances USING btree (match_id, alliance_color, station);


--
-- Name: idx_pit_scouting_entries_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_pit_scouting_entries_unique ON public.pit_scouting_entries USING btree (event_id, frc_team_id, user_id);


--
-- Name: idx_scouting_assignments_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_scouting_assignments_unique ON public.scouting_assignments USING btree (event_id, user_id, match_id);


--
-- Name: idx_scouting_entries_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_scouting_entries_unique ON public.scouting_entries USING btree (event_id, frc_team_id, match_id, user_id, scouting_mode);


--
-- Name: idx_team_event_summaries; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_team_event_summaries ON public.team_event_summaries USING btree (event_id, frc_team_id);


--
-- Name: idx_web_push_subscriptions_user_endpoint; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_web_push_subscriptions_user_endpoint ON public.web_push_subscriptions USING btree (user_id, endpoint);


--
-- Name: index_active_storage_attachments_on_blob_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_storage_attachments_on_blob_id ON public.active_storage_attachments USING btree (blob_id);


--
-- Name: index_active_storage_attachments_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_attachments_uniqueness ON public.active_storage_attachments USING btree (record_type, record_id, name, blob_id);


--
-- Name: index_active_storage_blobs_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_blobs_on_key ON public.active_storage_blobs USING btree (key);


--
-- Name: index_active_storage_variant_records_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_variant_records_uniqueness ON public.active_storage_variant_records USING btree (blob_id, variation_digest);


--
-- Name: index_data_conflicts_on_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_data_conflicts_on_event_id ON public.data_conflicts USING btree (event_id);


--
-- Name: index_data_conflicts_on_frc_team_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_data_conflicts_on_frc_team_id ON public.data_conflicts USING btree (frc_team_id);


--
-- Name: index_data_conflicts_on_match_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_data_conflicts_on_match_id ON public.data_conflicts USING btree (match_id);


--
-- Name: index_data_conflicts_on_resolved_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_data_conflicts_on_resolved_by_id ON public.data_conflicts USING btree (resolved_by_id);


--
-- Name: index_event_teams_on_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_event_teams_on_event_id ON public.event_teams USING btree (event_id);


--
-- Name: index_event_teams_on_event_id_and_frc_team_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_event_teams_on_event_id_and_frc_team_id ON public.event_teams USING btree (event_id, frc_team_id);


--
-- Name: index_event_teams_on_frc_team_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_event_teams_on_frc_team_id ON public.event_teams USING btree (frc_team_id);


--
-- Name: index_events_on_tba_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_events_on_tba_key ON public.events USING btree (tba_key);


--
-- Name: index_frc_teams_on_team_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_frc_teams_on_team_number ON public.frc_teams USING btree (team_number);


--
-- Name: index_game_configs_on_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_game_configs_on_active ON public.game_configs USING btree (active);


--
-- Name: index_game_configs_on_year; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_game_configs_on_year ON public.game_configs USING btree (year);


--
-- Name: index_match_alliances_on_frc_team_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_match_alliances_on_frc_team_id ON public.match_alliances USING btree (frc_team_id);


--
-- Name: index_match_alliances_on_match_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_match_alliances_on_match_id ON public.match_alliances USING btree (match_id);


--
-- Name: index_match_alliances_on_match_id_and_frc_team_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_match_alliances_on_match_id_and_frc_team_id ON public.match_alliances USING btree (match_id, frc_team_id);


--
-- Name: index_matches_on_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_matches_on_event_id ON public.matches USING btree (event_id);


--
-- Name: index_matches_on_tba_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_matches_on_tba_key ON public.matches USING btree (tba_key);


--
-- Name: index_pick_lists_on_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pick_lists_on_event_id ON public.pick_lists USING btree (event_id);


--
-- Name: index_pick_lists_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pick_lists_on_user_id ON public.pick_lists USING btree (user_id);


--
-- Name: index_pit_scouting_entries_on_client_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_pit_scouting_entries_on_client_uuid ON public.pit_scouting_entries USING btree (client_uuid);


--
-- Name: index_pit_scouting_entries_on_data; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pit_scouting_entries_on_data ON public.pit_scouting_entries USING gin (data);


--
-- Name: index_pit_scouting_entries_on_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pit_scouting_entries_on_event_id ON public.pit_scouting_entries USING btree (event_id);


--
-- Name: index_pit_scouting_entries_on_frc_team_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pit_scouting_entries_on_frc_team_id ON public.pit_scouting_entries USING btree (frc_team_id);


--
-- Name: index_pit_scouting_entries_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pit_scouting_entries_on_user_id ON public.pit_scouting_entries USING btree (user_id);


--
-- Name: index_predictions_on_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_predictions_on_event_id ON public.predictions USING btree (event_id);


--
-- Name: index_predictions_on_match_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_predictions_on_match_id ON public.predictions USING btree (match_id);


--
-- Name: index_scouting_assignments_on_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_scouting_assignments_on_event_id ON public.scouting_assignments USING btree (event_id);


--
-- Name: index_scouting_assignments_on_event_id_and_match_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_scouting_assignments_on_event_id_and_match_id ON public.scouting_assignments USING btree (event_id, match_id);


--
-- Name: index_scouting_assignments_on_frc_team_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_scouting_assignments_on_frc_team_id ON public.scouting_assignments USING btree (frc_team_id);


--
-- Name: index_scouting_assignments_on_match_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_scouting_assignments_on_match_id ON public.scouting_assignments USING btree (match_id);


--
-- Name: index_scouting_assignments_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_scouting_assignments_on_user_id ON public.scouting_assignments USING btree (user_id);


--
-- Name: index_scouting_entries_on_client_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_scouting_entries_on_client_uuid ON public.scouting_entries USING btree (client_uuid);


--
-- Name: index_scouting_entries_on_data; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_scouting_entries_on_data ON public.scouting_entries USING gin (data);


--
-- Name: index_scouting_entries_on_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_scouting_entries_on_event_id ON public.scouting_entries USING btree (event_id);


--
-- Name: index_scouting_entries_on_frc_team_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_scouting_entries_on_frc_team_id ON public.scouting_entries USING btree (frc_team_id);


--
-- Name: index_scouting_entries_on_match_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_scouting_entries_on_match_id ON public.scouting_entries USING btree (match_id);


--
-- Name: index_scouting_entries_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_scouting_entries_on_user_id ON public.scouting_entries USING btree (user_id);


--
-- Name: index_simulation_results_on_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_simulation_results_on_event_id ON public.simulation_results USING btree (event_id);


--
-- Name: index_simulation_results_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_simulation_results_on_user_id ON public.simulation_results USING btree (user_id);


--
-- Name: index_statbotics_caches_on_epa_mean; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_statbotics_caches_on_epa_mean ON public.statbotics_caches USING btree (epa_mean);


--
-- Name: index_statbotics_caches_on_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_statbotics_caches_on_event_id ON public.statbotics_caches USING btree (event_id);


--
-- Name: index_statbotics_caches_on_event_id_and_frc_team_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_statbotics_caches_on_event_id_and_frc_team_id ON public.statbotics_caches USING btree (event_id, frc_team_id);


--
-- Name: index_statbotics_caches_on_frc_team_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_statbotics_caches_on_frc_team_id ON public.statbotics_caches USING btree (frc_team_id);


--
-- Name: index_users_on_api_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_api_token ON public.users USING btree (api_token);


--
-- Name: index_users_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email ON public.users USING btree (email);


--
-- Name: index_users_on_reset_password_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_reset_password_token ON public.users USING btree (reset_password_token);


--
-- Name: index_users_on_username; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_username ON public.users USING btree (username);


--
-- Name: index_web_push_subscriptions_on_endpoint; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_web_push_subscriptions_on_endpoint ON public.web_push_subscriptions USING btree (endpoint);


--
-- Name: index_web_push_subscriptions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_web_push_subscriptions_on_user_id ON public.web_push_subscriptions USING btree (user_id);


--
-- Name: simulation_results fk_rails_1306ef9ab8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.simulation_results
    ADD CONSTRAINT fk_rails_1306ef9ab8 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: simulation_results fk_rails_1ed5e9f012; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.simulation_results
    ADD CONSTRAINT fk_rails_1ed5e9f012 FOREIGN KEY (event_id) REFERENCES public.events(id);


--
-- Name: match_alliances fk_rails_206fee0bd5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_alliances
    ADD CONSTRAINT fk_rails_206fee0bd5 FOREIGN KEY (match_id) REFERENCES public.matches(id);


--
-- Name: scouting_assignments fk_rails_22f020434b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scouting_assignments
    ADD CONSTRAINT fk_rails_22f020434b FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: event_teams fk_rails_27d2a44384; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.event_teams
    ADD CONSTRAINT fk_rails_27d2a44384 FOREIGN KEY (event_id) REFERENCES public.events(id);


--
-- Name: data_conflicts fk_rails_33ac680ec0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.data_conflicts
    ADD CONSTRAINT fk_rails_33ac680ec0 FOREIGN KEY (resolved_by_id) REFERENCES public.users(id);


--
-- Name: scouting_entries fk_rails_358962f828; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scouting_entries
    ADD CONSTRAINT fk_rails_358962f828 FOREIGN KEY (event_id) REFERENCES public.events(id);


--
-- Name: scouting_assignments fk_rails_397e4b711b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scouting_assignments
    ADD CONSTRAINT fk_rails_397e4b711b FOREIGN KEY (frc_team_id) REFERENCES public.frc_teams(id);


--
-- Name: statbotics_caches fk_rails_39f3bfa5d1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.statbotics_caches
    ADD CONSTRAINT fk_rails_39f3bfa5d1 FOREIGN KEY (event_id) REFERENCES public.events(id);


--
-- Name: pick_lists fk_rails_3b05876fb5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pick_lists
    ADD CONSTRAINT fk_rails_3b05876fb5 FOREIGN KEY (event_id) REFERENCES public.events(id);


--
-- Name: scouting_entries fk_rails_4939c4b7d2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scouting_entries
    ADD CONSTRAINT fk_rails_4939c4b7d2 FOREIGN KEY (frc_team_id) REFERENCES public.frc_teams(id);


--
-- Name: match_alliances fk_rails_4ab4b7f92e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_alliances
    ADD CONSTRAINT fk_rails_4ab4b7f92e FOREIGN KEY (frc_team_id) REFERENCES public.frc_teams(id);


--
-- Name: statbotics_caches fk_rails_4c3edc3178; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.statbotics_caches
    ADD CONSTRAINT fk_rails_4c3edc3178 FOREIGN KEY (frc_team_id) REFERENCES public.frc_teams(id);


--
-- Name: pit_scouting_entries fk_rails_54a8871f76; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pit_scouting_entries
    ADD CONSTRAINT fk_rails_54a8871f76 FOREIGN KEY (frc_team_id) REFERENCES public.frc_teams(id);


--
-- Name: event_teams fk_rails_5ce99f65e0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.event_teams
    ADD CONSTRAINT fk_rails_5ce99f65e0 FOREIGN KEY (frc_team_id) REFERENCES public.frc_teams(id);


--
-- Name: scouting_assignments fk_rails_63abad9228; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scouting_assignments
    ADD CONSTRAINT fk_rails_63abad9228 FOREIGN KEY (event_id) REFERENCES public.events(id);


--
-- Name: pick_lists fk_rails_641ec6d54c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pick_lists
    ADD CONSTRAINT fk_rails_641ec6d54c FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: matches fk_rails_7069ec1376; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.matches
    ADD CONSTRAINT fk_rails_7069ec1376 FOREIGN KEY (event_id) REFERENCES public.events(id);


--
-- Name: pit_scouting_entries fk_rails_7885593f98; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pit_scouting_entries
    ADD CONSTRAINT fk_rails_7885593f98 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: scouting_entries fk_rails_85360dc7d2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scouting_entries
    ADD CONSTRAINT fk_rails_85360dc7d2 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: predictions fk_rails_899a4f2cfe; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.predictions
    ADD CONSTRAINT fk_rails_899a4f2cfe FOREIGN KEY (event_id) REFERENCES public.events(id);


--
-- Name: active_storage_variant_records fk_rails_993965df05; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT fk_rails_993965df05 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: data_conflicts fk_rails_9a15a6f7b0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.data_conflicts
    ADD CONSTRAINT fk_rails_9a15a6f7b0 FOREIGN KEY (event_id) REFERENCES public.events(id);


--
-- Name: scouting_assignments fk_rails_a594d28feb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scouting_assignments
    ADD CONSTRAINT fk_rails_a594d28feb FOREIGN KEY (match_id) REFERENCES public.matches(id);


--
-- Name: scouting_entries fk_rails_aa056b440d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scouting_entries
    ADD CONSTRAINT fk_rails_aa056b440d FOREIGN KEY (match_id) REFERENCES public.matches(id);


--
-- Name: web_push_subscriptions fk_rails_b006f28dac; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.web_push_subscriptions
    ADD CONSTRAINT fk_rails_b006f28dac FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: data_conflicts fk_rails_b339fb035b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.data_conflicts
    ADD CONSTRAINT fk_rails_b339fb035b FOREIGN KEY (match_id) REFERENCES public.matches(id);


--
-- Name: active_storage_attachments fk_rails_c3b3935057; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT fk_rails_c3b3935057 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: data_conflicts fk_rails_cf41e98d82; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.data_conflicts
    ADD CONSTRAINT fk_rails_cf41e98d82 FOREIGN KEY (frc_team_id) REFERENCES public.frc_teams(id);


--
-- Name: pit_scouting_entries fk_rails_e96be0d8c3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pit_scouting_entries
    ADD CONSTRAINT fk_rails_e96be0d8c3 FOREIGN KEY (event_id) REFERENCES public.events(id);


--
-- Name: predictions fk_rails_efbcaaab9d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.predictions
    ADD CONSTRAINT fk_rails_efbcaaab9d FOREIGN KEY (match_id) REFERENCES public.matches(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260315103000'),
('20260310120000'),
('20260306100100'),
('20260306100000'),
('20260305183933'),
('20260305000000'),
('20260304154510'),
('20260304150742'),
('20260304043658'),
('20260303120000'),
('20260302210800'),
('20260302192708'),
('20260302020008'),
('20260302020007'),
('20260302020006'),
('20260302020005'),
('20260302020004'),
('20260302020003'),
('20260302020002'),
('20260302020001'),
('20260302020000'),
('20260302012107'),
('20260302004530'),
('20260302004524'),
('20260302004520'),
('20260302004515'),
('20260302004511'),
('20260302004507'),
('20260302004501'),
('20260302004457'),
('20260302004453'),
('20260302004449'),
('20260302004444'),
('20260302004440');
