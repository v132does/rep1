create or replace procedure it.PRP_OBT_DAT_LIBRADOR(P_COD_TIP_DOCUMENTO IN NUMBER, P_NRO_DOCUMENTO IN VARCHAR2,
                            P_NOM_COMPLETO IN OUT VARCHAR2, P_VTO_INFORME IN OUT DATE, P_EST_INFORME IN OUT VARCHAR2) is
begin
  SELECT nom_completo , fec_ven_informconf, est_informconf
	  into p_nom_completo, p_vto_informe, p_est_informe
	  FROM  pr_chq_libradores
	 WHERE nro_documento = p_nro_documento
	   AND COD_TIP_DOCUMENTO = p_cod_tip_documento;
Exception
  When NO_DATA_FOUND then
       null;
end;
/

