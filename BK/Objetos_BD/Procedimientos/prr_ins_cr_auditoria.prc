CREATE OR REPLACE PROCEDURE IT.PRR_INS_CR_AUDITORIA
 (RP_RAUDI IN CR_AUDITORIAS%ROWTYPE
 )
 IS
BEGIN
   if rp_raudi.detalle is not null then
      insert into cr_auditorias
      (tabla, clave, usuario,
       fec_sistema,  fec_calendario,
       tip_novedad,  origen,
       terminal, detalle)
      values
      (rp_raudi.tabla, rp_raudi.clave, USER,
       SYSDATE, rp_raudi.fec_calendario, rp_raudi.tip_novedad,
       PAE_CNF.G_PROGRAMA, PAE_CNF.FU_OBT_TERMINAL, rp_raudi.detalle);
    end if;
END;
/

