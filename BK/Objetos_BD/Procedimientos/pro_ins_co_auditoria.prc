CREATE OR REPLACE PROCEDURE IT.PRO_INS_CO_AUDITORIA
 (RP_OAUDI IN CO_AUDITORIAS%ROWTYPE
 )
 IS
BEGIN
  IF rp_oaudi.detalle IS NOT NULL THEN
    insert into co_auditorias( tabla,
                               clave,
                               usuario,
                               fec_sistema,
                               fec_calendario,
                               tip_novedad,
                               origen,
                               terminal,
                               detalle )
                       values( rp_oaudi.tabla,
                               rp_oaudi.clave,
                               USER,
                               SYSDATE,
                               rp_oaudi.fec_calendario,
                               rp_oaudi.tip_novedad,
                               pae_cnf.g_programa,
                               pae_cnf.fu_obt_terminal,
                               rp_oaudi.detalle );
  END IF;
END;
/

