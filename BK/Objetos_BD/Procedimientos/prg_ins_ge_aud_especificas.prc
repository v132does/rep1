CREATE OR REPLACE PROCEDURE IT.PRG_INS_GE_AUD_ESPECIFICAS
 (p_tabla in varchar2,
  p_clave IN varchar2,
  p_fecha in date,
  p_tip_novedad in varchar2,
  p_detalle in varchar2,
  p_ip in varchar2 default null
 )
 IS
 PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
   if p_detalle is not null then
      insert into ge_aud_especificas
      (tabla, clave, usuario,
       fec_sistema,  fec_calendario,
       tip_novedad,  origen,
       terminal, detalle)
      values
      (p_tabla, p_clave, USER,
       SYSDATE, p_fecha, p_tip_novedad,
       PAE_CNF.G_PROGRAMA, p_ip, p_detalle);
       commit;
   end if;
exception
  when others then
    null;
END;
/

