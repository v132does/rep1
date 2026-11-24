CREATE OR REPLACE PROCEDURE IT.PRQ_INS_CS_AUDITORIA
 (RP_CAUDI IN CS_AUDITORIAS%ROWTYPE
 )
 IS
BEGIN
   if rp_caudi.detalle is not null then
      insert into cs_auditorias
      (tabla, clave, usuario,
       fec_sistema,  fec_calendario,
       tip_novedad,  origen,
       terminal, detalle)
      values
      (rp_caudi.tabla, rp_caudi.clave, USER,
       SYSDATE, rp_caudi.fec_calendario, rp_caudi.tip_novedad,
       PAE_CNF.G_PROGRAMA, PAE_CNF.FU_OBT_TERMINAL, rp_caudi.detalle);
   end if;
END;
/

