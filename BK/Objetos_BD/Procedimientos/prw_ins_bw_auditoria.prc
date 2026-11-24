CREATE OR REPLACE PROCEDURE IT.PRW_INS_BW_AUDITORIA
 (RP_WAUDI IN BW_AUDITORIAS%ROWTYPE
 )
 IS
BEGIN
   if rp_waudi.detalle is not null then
      insert into bw_auditorias
      (tabla, clave, usuario,
       fec_sistema,  fec_calendario,
       tip_novedad,  origen,
       terminal, detalle)
      values
      (rp_waudi.tabla, rp_waudi.clave, USER,
       SYSDATE, rp_waudi.fec_calendario, rp_waudi.tip_novedad,
       PAE_CNF.G_PROGRAMA, PAE_CNF.FU_OBT_TERMINAL, rp_waudi.detalle);
   end if;
END;
/

