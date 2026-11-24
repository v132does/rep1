create or replace procedure it.PRP_INS_HIS_LIMITE(P_NRO_LINEA IN NUMBER) is
 v_estado pr_lineas.estado%type;
Begin
 Select estado into v_estado
   from pr_lineas
  where nro_linea = p_nro_linea;
 ---
 Insert into pr_lineas_his
    (nro_linea, cod_persona, cod_gru_economico, cod_modulo, cod_modalidad,
      cod_moneda, monto, fec_vencimiento, fec_otorgamiento, mto_aplicado,
      descripcion, estado, observacion, niv_aprobacion, cotizacion,
      fec_aprobacion, nro_acta, cod_campana, url_crm)
  Select nro_linea, cod_persona, cod_gru_economico, cod_modulo, cod_modalidad,
      cod_moneda, monto, fec_vencimiento, fec_otorgamiento, mto_aplicado,
      descripcion, estado, observacion, niv_aprobacion, cotizacion,
      fec_aprobacion, nro_acta, cod_campana, url_crm
    from pr_lineas
   where nro_linea = p_nro_linea;
 ---
 Insert into pr_lin_tip_garantias_his
    (nro_linea, cod_garantia, mto_limite, mto_aplicado, rel_garantia)
 select nro_linea, cod_garantia, mto_limite, mto_aplicado, rel_garantia
   from pr_lin_tip_garantias
  where nro_linea = p_nro_linea;
 ---
 Insert into pr_lin_tip_gar_mad_his
    (nro_linea, cod_garantia, cod_modulo, cod_modalidad, mto_limite, mto_aplicado)
 Select nro_linea, cod_garantia, cod_modulo, cod_modalidad, mto_limite, mto_aplicado
   from pr_lin_tip_gar_mad
  where nro_linea = p_nro_linea;
 ---
 If v_estado in ('A', 'R') Then
   Insert into pr_lin_aplicaciones_his
      (nro_linea, nro_sec_padre, nro_cuenta, cod_moneda, mto_aplicado)
   Select nro_linea, nro_sec_padre, nro_cuenta, cod_moneda, mto_aplicado
     from pr_lin_aplicaciones
    where nro_linea = p_nro_linea;
 Else
   Insert into pr_lin_aplicaciones_his
      (nro_linea, nro_sec_padre, nro_cuenta, cod_moneda, mto_aplicado)
   select nro_linea, nro_sec_padre, nro_cuenta, cod_moneda, decode(cod_modulo, 6, saldo, monto)
     from pv_operaciones
    where nro_linea = p_nro_linea;
 End if;
 ---
Exception
	when others then
    if sqlcode <= -20000 then
       raise;
    else
       raise_application_error(-20000, 'Error al insertar historico de limite: '||p_nro_linea||' '||sqlerrm);
    end if;
End PRP_INS_HIS_LIMITE;
/

