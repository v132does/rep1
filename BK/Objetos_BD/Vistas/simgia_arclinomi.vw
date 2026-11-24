create or replace force view it.simgia_arclinomi as
select  ge.cod_persona CLIENPAGN,
        ge.cod_persona CLIENCOBN,
        0 CLIENFUM


 --from  table(pai_int.obtieneArclinomi()) a , ge_entes ge where a.cod_ente like ge.cod_ente(+);
 FROM ge_entes a, ge_entes ge WHERE a.cod_ente = ge.cod_ente
;

