CREATE OR REPLACE PROCEDURE IT.PRX_INS_CX_AUDITORIA
 (RP_GAUDI IN CX_AUDITORIAS%ROWTYPE
 )
 IS
BEGIN
   if rp_gaudi.detalle is not null then
      insert into cx_auditorias
      (tabla, clave, usuario,
       fec_sistema,  fec_calendario,
       tip_novedad,  origen,
       terminal, detalle)
      values
      (rp_gaudi.tabla, rp_gaudi.clave, USER,
       SYSDATE, rp_gaudi.fec_calendario, rp_gaudi.tip_novedad,
       PAE_CNF.G_PROGRAMA, PAE_CNF.FU_OBT_TERMINAL, rp_gaudi.detalle);
   end if;
END;
/

