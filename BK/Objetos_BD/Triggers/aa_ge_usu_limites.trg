CREATE OR REPLACE TRIGGER IT.AA_GE_USU_LIMITES
 AFTER DELETE OR UPDATE
 ON GE_USU_LIMITES
 FOR EACH ROW
DECLARE
r_gaudi ge_auditorias%rowtype; -- Registro de la tabla GE_AUDITORIAS
BEGIN

   r_gaudi.tabla := 'GE_USU_LIMITES';
   r_gaudi.clave := :old.cod_usuario||'#'||:old.cod_moneda||'#'
                    ||to_char(:old.cod_modulo)||'#'||to_char(:old.cod_modalidad)||'#'||
                    to_char(:old.niv_aprobacion)||'#'||:old.categoria;
   r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
   if updating then
      r_gaudi.tip_novedad := 'M';
   elsif deleting then
      r_gaudi.tip_novedad := 'E';
   end if;
   --- Registrar Detalle

    r_gaudi.detalle := pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'MTO_MAXIMO',:old.mto_maximo,:new.mto_maximo,'M');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'CATEGORIA'     ,:old.categoria     , :new.categoria         );
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'NIV_APROBACION',:old.niv_aprobacion, :new.niv_aprobacion    );
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'PUN_TASAS'     ,:old.pun_tasas     , :new.pun_tasas     ,'M');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'PUN_COTIZACION',:old.pun_cotizacion, :new.pun_cotizacion,'M');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_OFICINA'   ,:old.cod_oficina   , :new.cod_oficina   ,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_MONEDA'    ,:old.cod_moneda    , :new.cod_moneda        );
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_MODULO'    ,:old.cod_modulo    , :new.cod_modulo        );
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_MODALIDAD' ,:old.cod_modalidad , :new.cod_modalidad     );


   --- Insertar tabla de auditoria
   PRG_INS_GE_AUDITORIA(r_gaudi);

END;
/

