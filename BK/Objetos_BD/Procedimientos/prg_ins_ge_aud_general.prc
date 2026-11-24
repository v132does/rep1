CREATE OR REPLACE PROCEDURE IT.PRG_INS_GE_AUD_GENERAL
 (p_tip_novedad in varchar2,
  p_condicion   in varchar2,
  p_cod_persona in varchar2,
  p_nro_documento in varchar2,
  p_terminal    in varchar2
 )
 IS
 PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
      insert into ge_aud_general
      (condicion,
       novedad,
       terminal,
       origen,
       cod_persona,
       nro_documento)
      values
      (p_condicion,
       p_tip_novedad,
       p_terminal,
       PAE_CNF.G_PROGRAMA,
       p_cod_persona,
       p_nro_documento);
       commit;
exception
  when others then
    null;
END;
/
