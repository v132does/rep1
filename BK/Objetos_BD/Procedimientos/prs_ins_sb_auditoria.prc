CREATE OR REPLACE PROCEDURE IT.PRS_INS_SB_AUDITORIA
 (RG_GAUDI IN SB_AUDITORIAS%ROWTYPE
 )
 IS
BEGIN
   if rg_gaudi.detalle is not null then
      insert into sb_auditorias
      (tabla, clave, usuario,
       fec_sistema,  fec_calendario,
       tip_novedad,  origen,
       terminal, detalle)
      values
      (rg_gaudi.tabla, rg_gaudi.clave, user,
       sysdate, rg_gaudi.fec_calendario, rg_gaudi.tip_novedad,
       pae_cnf.g_programa, pae_cnf.fu_obt_terminal, rg_gaudi.detalle);
   end if;
END;
/

