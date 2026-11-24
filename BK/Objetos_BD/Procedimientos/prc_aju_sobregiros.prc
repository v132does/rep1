CREATE OR REPLACE PROCEDURE IT.PRC_AJU_SOBREGIROS
 IS
   /************************************************************/
   /*	 Nombre: PRC_AJU_SOBREGIRO                               */
   /*	 Hecho Por: Lic. Julio Cesar Leguizamon G.               */
   /*	 Fecha: 15/12/2006                                       */
   /*	 Objetivo: generar los asientos automaticos por los      */
	 /*  ajustes de las lineas de sobregiro utilizadas que deben */
	 /*  contabilizarse en cuentas de contingencia a fin de      */
	 /*  registrar el riesgo                                     */
	 /*  INVENTARIO CLINLISB                                     */
   /************************************************************/

rv_gcale 						 						ge_calendarios%rowtype;
v_fcdehoy 											date;
v_fcanter 											ge_calendarios.fec_anterior%type;
v_nro_asiento										cb_asi_automaticos.nro_asiento%type;
v_nro_linea											ge_tip_asientos.nro_linea%type := 1;
v_cod_tip_asiento								ge_transacciones.cod_tip_asiento%type;
v_des_transaccion								ge_transacciones.descripcion%type;
v_cod_tip_asiento2							ge_transacciones.cod_tip_asiento2%type;
v_cod_moneda										ba_monedas.cod_moneda%type;
v_cod_sec_contable							ge_tip_asientos.cod_sec_contable%type;
v_residente											ge_clientes.residente%type;
v_mto_mon_rubro									ge_movimientos.monto%type;
v_cod_mon_local 								ba_monedas.cod_moneda%type;
v_mto_mon_local									ge_movimientos.monto%type;
v_cod_rubro											cb_asi_automaticos_det.cod_rubro%type;
v_redondeo_ml                   number(5);

--Acumula por oficina, moneda, sector contable, residente, tip_deudor...todos
--los saldos de lineas sin utilizar
--modificaciones de BBVA 22/08/11 Juan José Estigarribia
cursor sobregiros is
select cod_oficina, cod_moneda, cotizacion, cod_sec_contable, residente, cod_tip_deudor, sum(sal_linea) monto
  from (select c.cod_oficina, c.cod_moneda, decode(c.cod_moneda, pag_gen.fu_obt_mon_local,0,pag_gen.fu_obt_cotizacion(c.cod_moneda, v_fcdehoy)) cotizacion,
               FUG_OBT_SEC_CONTABLE (g.cod_persona) cod_sec_contable,FUG_OBT_RES_CLIENTE (g.cod_persona) residente,FUG_OBT_TIP_DEUDOR (g.cod_persona) cod_tip_deudor,
              /* d.cod_sec_contable, d.residente, d.cod_tip_deudor,*/
            case when sal_total < 0 then
              case when (abs(sal_total)+sal_retenido+sal_bloqueado) <= pag_cta.fu_obt_lin_sobregiro(c.nro_cuenta,v_fcdehoy) then
                pag_cta.fu_obt_lin_sobregiro(c.nro_cuenta,v_fcdehoy) - (abs(sal_total)+sal_retenido++sal_bloqueado)
              else
                0
              end
            else
              case when (sal_total-sal_retenido-sal_bloqueado) > 0 then
                pag_cta.fu_obt_lin_sobregiro(c.nro_cuenta,v_fcdehoy)
              else
                case when abs(sal_total-sal_retenido-sal_bloqueado) > pag_cta.fu_obt_lin_sobregiro(c.nro_cuenta,v_fcdehoy) then
                  0
                else
                  pag_cta.fu_obt_lin_sobregiro(c.nro_cuenta,v_fcdehoy) - abs(sal_total-sal_retenido-sal_bloqueado)
                end
              end
            end sal_linea
        from cc_cta_corrientes c, ge_cta_clientes g/* ge_clientes d*/
        where c.nro_cuenta=g.nro_cuenta 
        and g.relacion='P' 
        and c.estado not in ('A','C','X')
        and c.cod_ente is not null -- ICL 22/03/2012 Mail HB: Solo contabilizar Plan Nómina
        and fuc_obt_exi_sobregiro(c.nro_cuenta) = 'S'
        /*and exists (select 1
                    from cc_lin_sobregiros
                    where estado = 'A'
                    and nro_cuenta = c.nro_cuenta)
        and c.nro_cuenta = g.nro_cuenta
        and g.relacion = 'P'
        and g.cod_persona = d.cod_persona*/
        )
  group by cod_oficina, cod_moneda, cotizacion, cod_sec_contable, residente, cod_tip_deudor
  having sum(sal_linea) <> 0; -- 06-jun-2007 - para que no genere asientos con monto 0
--Recuperar los asientos de contabilizacion de contingencia del dia anterior para cancelar
cursor asientos is
  select cod_oficina, nro_asiento, nro_linea, cod_rubro, decode(tip_movimiento,'C','D','C') tip_movimiento,
  mto_mon_rubro, mto_mon_local, 'Canc. Contingencia fecha '||to_char(v_fcanter,'dd/mm/yyyy')||' Oficina '||cod_oficina descripcion,
  referencia, protegido, actualizado, val_cotizacion, distribuido, ref_movimiento, cod_modulo, cod_modalidad, cod_ofi_origen
  from cb_asi_automaticos_det
  where fecha = v_fcanter
  and referencia = 'CONTI.LINEA'
  and descripcion not like '%Canc. Contingencia fecha%';

cursor c_tip_asientos is
  select * from ge_tip_asientos
  where cod_tip_asiento in (v_cod_tip_asiento,v_cod_tip_asiento2) and
  cod_moneda = v_cod_moneda and
  (cod_sec_contable = v_cod_sec_contable or cod_sec_contable is null) and
  (ind_residente = v_residente or ind_residente = 'X');


/******************************************************************************/
--BLOQUE PRINCIPAL
/******************************************************************************/
BEGIN
  v_fcdehoy := pag_cal.fu_obt_fec_actual(3);
  rv_gcale  := pag_cal.fu_obt_reg_cal(3);
  v_fcanter := rv_gcale.fec_anterior;
  v_nro_asiento := fug_obt_pardinamico('SIG_NRO_ASI_AUTOM');

   --Obtiene la Moneda Local
  v_cod_mon_local      := pag_gen.fu_obt_mon_local;

	 --Cancelar la contabilizacion de contingencia de la fecha anterior
	for reg in asientos loop
    begin
  		insert into cb_asi_automaticos_det
      (fecha, cod_oficina, nro_asiento, nro_linea, cod_rubro,
  		tip_movimiento, mto_mon_rubro, mto_mon_local, descripcion, referencia,
  		protegido, actualizado, val_cotizacion, distribuido, ref_movimiento,
  		cod_modulo, cod_modalidad, cod_ofi_origen)
      values
      (v_fcdehoy, reg.cod_oficina, v_nro_asiento, reg.nro_linea, reg.cod_rubro,
  		reg.tip_movimiento, reg.mto_mon_rubro, reg.mto_mon_local, reg.descripcion, reg.referencia,
  		reg.protegido, reg.actualizado, reg.val_cotizacion, reg.distribuido, reg.ref_movimiento,
  		reg.cod_modulo, reg.cod_modalidad, reg.cod_ofi_origen);

      v_nro_linea := v_nro_linea + 1;
		exception
  		when others then
      raise_application_error(-20000,'Error al insertar cb_asi_automaticos_det '||sqlerrm);
		end;
	end loop;

  --Rescuperar asiento relacionado a la transaccion
	begin
    select cod_tip_asiento, descripcion, cod_tip_asiento2
    into v_cod_tip_asiento, v_des_transaccion, v_cod_tip_asiento2
    from ge_transacciones
    where cod_modulo = 4
    and cod_modalidad = 41
    and cod_transaccion = 920
    and cod_tip_asiento is not null;
  exception
  when no_data_found then
    raise_application_error(-20000,'Transaccion 41-920 no tiene asiento relacionado');
  when others then
    raise_application_error(-20001,'Error al recuperar asiento de ge_transacciones');
  end;

  --Contabilizar la contingencia de sobregiros del dia
  v_redondeo_ml := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',4,41,v_cod_mon_local);
	for reg in sobregiros loop
    v_cod_sec_contable	:= reg.cod_sec_contable;
    v_residente					:= reg.residente;
		v_cod_moneda				:= reg.cod_moneda;

		--Si la moneda es distinta a la moneda local se graba en mto_mon_rubro
		if v_cod_mon_local <> reg.cod_moneda then
  		v_mto_mon_rubro := reg.monto;
			v_mto_mon_local := round((reg.monto * reg.cotizacion),v_redondeo_ml);
		else
  		v_mto_mon_rubro := 0;
			v_mto_mon_local := reg.monto;
		end if;

    begin
			for reg2 in c_tip_asientos loop
        begin
					if reg2.ind_deudor = 'S' then
            v_cod_rubro := substr(reg2.cod_rubro,1,8)||ltrim(to_char(reg.cod_tip_deudor,'00'))||substr(reg2.cod_rubro,11,5);
          else
            v_cod_rubro := reg2.cod_rubro;
          end if;

          insert into cb_asi_automaticos_det
          (fecha, cod_oficina, nro_asiento, nro_linea, cod_rubro,
          tip_movimiento, mto_mon_rubro, mto_mon_local, descripcion, referencia,
          protegido, actualizado, val_cotizacion, distribuido, ref_movimiento,
          cod_modulo, cod_modalidad, cod_ofi_origen)
          values
          (v_fcdehoy, reg.cod_oficina, v_nro_asiento, v_nro_linea, v_cod_rubro,
          reg2.tip_movimiento, v_mto_mon_rubro, v_mto_mon_local, 'Contingencia de sobregiros fecha '||to_char(v_fcdehoy,'dd/mm/yyyy')||' Oficina '||reg.cod_oficina, 'CONTI.LINEA',
          'N'/*reg.protegido*/, 'N'/*reg.actualizado*/, reg.cotizacion/*reg.val_cotizacion*/, 'N'/*reg.distribuido*/, null/*reg.ref_movimiento*/,
          4/*reg.cod_modulo*/, 41/*reg.cod_modalidad*/, 1/*reg.cod_ofi_origen*/);

          v_nro_linea := v_nro_linea + 1;
          exception
            when others then
            raise_application_error(-20000,'Error al insertar cb_asi_automaticos_det '||sqlerrm);
        end;
			end loop;
		end;
	end loop;
end;
/

