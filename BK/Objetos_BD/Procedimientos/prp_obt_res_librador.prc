create or replace procedure it.prp_obt_res_librador(
   p_cod_tip_documento in number,
   p_nro_documento in varchar2,
   p_tot_cheques in out number,
   p_tot_deposito in out number) is

	 v_cdmoned varchar2(3);
	 v_cotizac ge_cotizaciones.val_conversion%type;
	 v_nombre  ba_personas.nom_completo%type;
Begin
	 v_cdmoned := pag_gen.fu_obt_mon_local;
	 v_cotizac := pag_gen.fu_obt_cotizacion(pag_gen.fu_obt_mon_fuerte,pag_cal.fu_obt_fec_actual(6));

	 Select sum(decode(c.cod_moneda , v_cdmoned,
              nvl(c.monto, 0),
              nvl(c.monto, 0) * v_cotizac)) Total,
	        sum(decode(c.estado, 'D',(decode(c.cod_moneda , v_cdmoned,
              nvl(c.monto, 0),
              nvl(c.monto, 0) * v_cotizac)), 0))
     into p_tot_cheques, p_tot_deposito
     from  ge_che_custodias c, pr_rel_chq_lib r
		where r.cod_banco     = c.cod_banco
 	    and r.nro_cheque    = c.nro_cheque
      and r.cta_libradora = c.cta_libradora
      and r.nro_documento = p_nro_documento
      AND R.COD_TIP_DOCUMENTO = p_cod_tip_documento;
end;
/

