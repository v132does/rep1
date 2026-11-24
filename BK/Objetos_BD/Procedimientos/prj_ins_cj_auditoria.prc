CREATE OR REPLACE PROCEDURE IT.PRJ_INS_CJ_AUDITORIA
 (RP_JAUDI IN CJ_AUDITORIAS%ROWTYPE
 )
 IS
BEGIN
   if rp_jaudi.detalle is not null then
      insert into cj_auditorias
      (tabla, clave, usuario,
       fec_sistema,  fec_calendario,
       tip_novedad,  origen,
       terminal, detalle)
      values
      (rp_jaudi.tabla, rp_jaudi.clave, USER,
       SYSDATE, rp_jaudi.fec_calendario, rp_jaudi.tip_novedad,
       PAE_CNF.G_PROGRAMA, PAE_CNF.FU_OBT_TERMINAL, rp_jaudi.detalle);
   end if;
END;
/

