begin  pre_ini_aplicacion;  pae_cnf.g_cod_modulo := 1; end; 
/


alter table PR_PRE_CHE_ROGA_TMP
add  DESTINO VARCHAR2(100);

alter table PR_PRE_CHE_ROGA_TMP
add  EJECUTORA VARCHAR2(100);

alter table PR_PRE_CHE_ROGA_TMP
add  TIPO VARCHAR2(100);

alter table PR_PRE_CHE_ROGA
add  DESTINO VARCHAR2(100);

alter table PR_PRE_CHE_ROGA
add  EJECUTORA VARCHAR2(100);

alter table PR_PRE_CHE_ROGA
add  TIPO VARCHAR2(100);

