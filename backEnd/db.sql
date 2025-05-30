--
-- PostgreSQL database dump
--

-- Dumped from database version 14.17 (Ubuntu 14.17-0ubuntu0.22.04.1)
-- Dumped by pg_dump version 14.17 (Ubuntu 14.17-0ubuntu0.22.04.1)

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
-- Name: joueurs; Type: TABLE; Schema: public; Owner: zack
--

CREATE TABLE public.joueurs (
    id integer NOT NULL,
    nom character varying(255) NOT NULL,
    mu double precision DEFAULT 25.0,
    sigma double precision DEFAULT 8.333,
    score_trueskill double precision GENERATED ALWAYS AS ((mu - ((3)::double precision * sigma))) STORED,
    tier character(1) DEFAULT 'C'::bpchar,
    CONSTRAINT joueurs_tier_check CHECK ((tier = ANY (ARRAY['S'::bpchar, 'A'::bpchar, 'B'::bpchar, 'C'::bpchar])))
);


ALTER TABLE public.joueurs OWNER TO zack;

--
-- Name: joueurs_id_seq; Type: SEQUENCE; Schema: public; Owner: zack
--

CREATE SEQUENCE public.joueurs_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.joueurs_id_seq OWNER TO zack;

--
-- Name: joueurs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: zack
--

ALTER SEQUENCE public.joueurs_id_seq OWNED BY public.joueurs.id;


--
-- Name: participations; Type: TABLE; Schema: public; Owner: zack
--

CREATE TABLE public.participations (
    joueur_id integer NOT NULL,
    tournoi_id integer NOT NULL,
    score integer NOT NULL
);


ALTER TABLE public.participations OWNER TO zack;

--
-- Name: tournois; Type: TABLE; Schema: public; Owner: zack
--

CREATE TABLE public.tournois (
    id integer NOT NULL,
    date date NOT NULL
);


ALTER TABLE public.tournois OWNER TO zack;

--
-- Name: tournois_id_seq; Type: SEQUENCE; Schema: public; Owner: zack
--

CREATE SEQUENCE public.tournois_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tournois_id_seq OWNER TO zack;

--
-- Name: tournois_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: zack
--

ALTER SEQUENCE public.tournois_id_seq OWNED BY public.tournois.id;


--
-- Name: joueurs id; Type: DEFAULT; Schema: public; Owner: zack
--

ALTER TABLE ONLY public.joueurs ALTER COLUMN id SET DEFAULT nextval('public.joueurs_id_seq'::regclass);


--
-- Name: tournois id; Type: DEFAULT; Schema: public; Owner: zack
--

ALTER TABLE ONLY public.tournois ALTER COLUMN id SET DEFAULT nextval('public.tournois_id_seq'::regclass);


--
-- Data for Name: joueurs; Type: TABLE DATA; Schema: public; Owner: zack
--

COPY public.joueurs (id, nom, mu, sigma, tier) FROM stdin;
1	Bloom	31.675043839695682	6.65574802799859	A
2	Dead	25.000000000003908	6.207687222180877	B
3	Lom	18.324956160300392	6.65574802799973	C
7	Diana	16.79369566862754	6.347890085277039	C
5	Bob	29.438890907539797	4.5015819828434	S
6	Charlie	24.06515389997999	4.4349853620504955	A
8	Kemory	20.87742193879531	5.35308280599353	B
9	EvoByTheWind	15.610657747204137	6.0385621135883305	C
10	Kakania	35.21636801768912	6.102430336929139	S
11	Einrich	30.193304335959336	5.57865331567219	A
4	Alice	30.68363183906573	4.542891378077342	S
\.


--
-- Data for Name: participations; Type: TABLE DATA; Schema: public; Owner: zack
--

COPY public.participations (joueur_id, tournoi_id, score) FROM stdin;
1	2	120
2	2	100
3	2	50
4	3	100
5	3	90
6	3	80
7	3	70
4	4	95
5	4	85
6	4	75
8	4	65
9	4	15
10	5	100
11	5	80
4	5	75
\.


--
-- Data for Name: tournois; Type: TABLE DATA; Schema: public; Owner: zack
--

COPY public.tournois (id, date) FROM stdin;
2	1000-12-12
3	2025-04-15
4	2025-04-16
5	2025-05-07
\.


--
-- Name: joueurs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: zack
--

SELECT pg_catalog.setval('public.joueurs_id_seq', 11, true);


--
-- Name: tournois_id_seq; Type: SEQUENCE SET; Schema: public; Owner: zack
--

SELECT pg_catalog.setval('public.tournois_id_seq', 5, true);


--
-- Name: joueurs joueurs_nom_key; Type: CONSTRAINT; Schema: public; Owner: zack
--

ALTER TABLE ONLY public.joueurs
    ADD CONSTRAINT joueurs_nom_key UNIQUE (nom);


--
-- Name: joueurs joueurs_pkey; Type: CONSTRAINT; Schema: public; Owner: zack
--

ALTER TABLE ONLY public.joueurs
    ADD CONSTRAINT joueurs_pkey PRIMARY KEY (id);


--
-- Name: participations participations_pkey; Type: CONSTRAINT; Schema: public; Owner: zack
--

ALTER TABLE ONLY public.participations
    ADD CONSTRAINT participations_pkey PRIMARY KEY (joueur_id, tournoi_id);


--
-- Name: tournois tournois_date_key; Type: CONSTRAINT; Schema: public; Owner: zack
--

ALTER TABLE ONLY public.tournois
    ADD CONSTRAINT tournois_date_key UNIQUE (date);


--
-- Name: tournois tournois_pkey; Type: CONSTRAINT; Schema: public; Owner: zack
--

ALTER TABLE ONLY public.tournois
    ADD CONSTRAINT tournois_pkey PRIMARY KEY (id);


--
-- Name: participations participations_joueur_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zack
--

ALTER TABLE ONLY public.participations
    ADD CONSTRAINT participations_joueur_id_fkey FOREIGN KEY (joueur_id) REFERENCES public.joueurs(id) ON DELETE CASCADE;


--
-- Name: participations participations_tournoi_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zack
--

ALTER TABLE ONLY public.participations
    ADD CONSTRAINT participations_tournoi_id_fkey FOREIGN KEY (tournoi_id) REFERENCES public.tournois(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

