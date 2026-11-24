CREATE OR REPLACE PROCEDURE IT.PRC_CAL_INT_SOB_VENCIDOS
 IS
 --calcula interes de operaciones vencidas
cursor cuentas is
    select nro_cuenta,cod_moneda,val_tasa,sal_total,mto_interes, dia_atraso, estado,
           cod_modulo, cod_modalidad, cod_oficina
      from ge_ope_vencidas
     where estado <> 'C'
       and cod_modulo    = 4  --
       and cod_modalidad = 49
    for update of mto_interes;
  v_fcdehoy       date;
  v_fecant        date;
  v_dias_tra      ge_ope_vencidas.dia_atraso%type;
  v_dias_total    ge_ope_vencidas.dia_atraso%type;
  v_moratorio     ge_ope_vencidas.mto_interes%type;
  v_cod_oficina   ge_ope_vencidas.cod_oficina%type;
  v_monlocal      ge_ope_vencidas.cod_moneda%type;
  v_punitorio     ge_ope_vencidas.mto_int_punitorio%type;
  v_impuesto      ge_ope_vencidas.mto_impuesto%type;
  v_estado        ge_ope_vencidas.estado%type;
  v_hora          ge_movimientos.hora%type := to_char(sysdate,'hh24:mi:ss');
  v_nro_secuencia ge_movimientos.nro_secuencia%type:=1;
  r_gmovi         ge_movimientos%rowtype;
  v_redondeo_ml   number(5);
  v_redondeo      number(5);
begin
  v_fcdehoy  := pag_cal.fu_obt_fec_actual(4);
  v_monlocal := pag_gen.fu_obt_mon_local;
  r_gmovi.cod_usuario     := user;
  r_gmovi.hora            := v_hora;
  r_gmovi.fecha           := v_fcdehoy;

  --Obtener oficina del usuario
  select cod_oficina
    into v_cod_oficina 
    from ba_usuarios
   where cod_usuario = user;
  
  v_fecant   := pag_cal.fu_obt_fec_ant_hab(v_fcdehoy,v_cod_oficina,1);--para contar findes y/o feriados
  v_dias_tra := v_fcdehoy - v_fecant; --dias trascurridos
  v_redondeo_ml := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',4,49,v_monlocal);
  for ctas in cuentas loop
    v_estado := null;
    --dias de atraso de la cuenta + los dias de calculo
    v_dias_total := v_dias_tra + ctas.dia_atraso;   
    If ctas.cod_moneda = v_monlocal then
      --calculo de interes diario,(no es necesario el interes,ya q el moratorio es lo q empieza a correr)
      v_moratorio := round((ctas.val_tasa * ctas.sal_total * v_dias_tra)/36500,v_redondeo_ml);
      v_punitorio := round((v_moratorio * 30)/100,v_redondeo_ml);
      if v_dias_total > 365 then
         v_impuesto := round(((ctas.sal_total + v_moratorio + v_punitorio) * 1.74)/100,v_redondeo_ml);
      else  --x la cantidad de dias
         v_impuesto := round(((ctas.sal_total + v_moratorio + v_punitorio) * 1.74 * v_dias_tra)/36500,v_redondeo_ml);
      end if;
    else
      v_redondeo  := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',4,49,ctas.cod_moneda);
      v_moratorio := round((ctas.val_tasa * ctas.sal_total * v_dias_tra)/36500,v_redondeo);
      v_punitorio := round((v_moratorio * 30)/100,v_redondeo);
      if v_dias_total >= 365 then
         v_impuesto := round(((ctas.sal_total + v_moratorio + v_punitorio) * 1.74)/100,v_redondeo);
      else--x dias
         v_impuesto := round(((ctas.sal_total + v_moratorio + v_punitorio) * 1.74 * v_dias_tra)/36500,v_redondeo);
      end if;
    End if;
    --ver si cambia de estado
    IF v_dias_total <= 89 THEN
       v_estado := 'V'; 
    ELSIF v_dias_total between 90 and 179 THEN
       v_estado := 'G';
    ELSIF v_dias_total between 180 and 359 THEN
       v_estado := 'M';
    ELSif v_dias_total >= 360 then
       v_estado := 'I';
    END IF;
    if ctas.nro_cuenta is not null then null; end if;
    update ge_ope_vencidas
       set mto_int_moratorio = nvl(mto_int_moratorio,0) + nvl(v_moratorio,0),
           sal_int_moratorio = nvl(sal_int_moratorio,0) + nvl(v_moratorio,0),
           mto_int_punitorio = nvl(mto_int_punitorio,0) + nvl(v_punitorio,0),
           sal_int_punitorio = nvl(sal_int_punitorio,0) + nvl(v_punitorio,0),
           mto_impuesto = nvl(mto_impuesto,0) + nvl(v_impuesto,0),
           sal_impuesto = nvl(sal_impuesto,0) + nvl(v_impuesto,0),
           dia_atraso  = nvl(dia_atraso,0)  + v_dias_tra,
           estado = decode(v_estado,null,estado,v_estado),
           fec_cam_estado = decode(v_estado,null,fec_cam_estado,v_fcdehoy)
    where current of cuentas;
    If sql%notfound then
      raise_application_error(-20000,'Actualizar Oper.Vencida');
    End if;
    --si hubo cambio de estado
    if ctas.estado <> nvl(v_estado,ctas.estado) then
      --generar movimiento x el cambio de estado
			  r_gmovi.nro_secuencia   := v_nro_secuencia;
			  r_gmovi.cod_modulo      := ctas.cod_modulo;
			  r_gmovi.cod_modalidad   := ctas.cod_modalidad;
			  r_gmovi.cod_oficina     := ctas.cod_oficina;
			  r_gmovi.cod_moneda      := ctas.cod_moneda;
           r_gmovi.nro_cuenta      := ctas.nro_cuenta;
			  r_gmovi.fec_valor       := v_fcdehoy;
			  r_gmovi.cod_tra_padre   := 401;
			  r_gmovi.cod_mod_padre   := ctas.cod_modulo;
			  r_gmovi.cod_mad_padre   := ctas.cod_modalidad;
			  r_gmovi.cod_transaccion := 401; 
			  r_gmovi.cod_ofi_origen  := v_cod_oficina;
			  r_gmovi.concepto        := 'Cambio de estado Operacion Vencida';
			  r_gmovi.emi_aviso       := 'N';
			  r_gmovi.estado          := 'N';
			  r_gmovi.reversado       := 'N';
           r_gmovi.protegido       := 'N';
           r_gmovi.est_cuenta      := v_estado;
           pag_gen.PR_INS_GE_MOVIMIENTO(r_gmovi);
	 		  -- Aumento la secuencia
			  v_nro_secuencia := v_nro_secuencia + 1;
    end if;
  end loop;
exception
  when others then
    If sqlcode <= -20000 then
      raise;
    else
      raise_application_error(-20001,'Actualizar Oper.Vencida '||sqlerrm);
    End if;
end;
/

