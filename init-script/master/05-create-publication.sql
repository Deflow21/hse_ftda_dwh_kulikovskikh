-- init-script/master/05-create-publication.sql

CREATE PUBLICATION my_publication FOR TABLE public.bookings, public.flights, public.tickets;