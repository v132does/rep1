CREATE OR REPLACE PROCEDURE IT.PRI_INS_IG_AUDITORIA
 (RP_IAUDI IN IG_AUDITORIAS%ROWTYPE
 )
 IS
BEGIN
  if rp_iaudi.detalle is not null then
    insert into ig_auditorias
      (tabla, clave, usuario,
       fec_sistema,  fec_calendario,
       tip_novedad,  origen,
       terminal, detalle)
    values
      (rp_iaudi.tabla, rp_iaudi.clave, USER,
       SYSDATE, rp_iaudi.fec_calendario, rp_iaudi.tip_novedad,
       PAE_CNF.G_PROGRAMA, PAE_CNF.FU_OBT_TERMINAL, rp_iaudi.detalle);
  End if;
END;
/

