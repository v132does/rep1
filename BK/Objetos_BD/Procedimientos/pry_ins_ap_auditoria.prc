CREATE OR REPLACE PROCEDURE IT.PRY_INS_AP_AUDITORIA
 (RP_EAUDI IN AP_AUDITORIAS%ROWTYPE
 )
 IS
BEGIN
   if rp_eaudi.detalle is not null then
      insert into ap_auditorias
      (tabla, clave, usuario,
       fec_sistema,  fec_calendario,
       tip_novedad,  origen,
       terminal, detalle)
       values
       (rp_eaudi.tabla, rp_eaudi.clave, USER,
       SYSDATE, rp_eaudi.fec_calendario, rp_eaudi.tip_novedad,
       PAE_CNF.G_PROGRAMA, pae_cnf.fu_obt_terminal, rp_eaudi.detalle);
    end if;
END;
/

