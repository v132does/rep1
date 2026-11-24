CREATE OR REPLACE PROCEDURE IT.PRB_INS_CB_AUDITORIA
 (RP_BAUDI IN CB_AUDITORIAS%ROWTYPE
 )
 IS
BEGIN
   if rp_baudi.detalle is not null then
      insert into cb_auditorias
      (tabla, clave, usuario,
       fec_sistema,  fec_calendario,
       tip_novedad,  origen,
       terminal, detalle)
      values
      (rp_baudi.tabla, rp_baudi.clave, USER,
       SYSDATE, rp_baudi.fec_calendario, rp_baudi.tip_novedad,
       PAE_CNF.G_PROGRAMA, PAE_CNF.FU_OBT_TERMINAL, rp_baudi.detalle);
   end if;
END;
/

