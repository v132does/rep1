CREATE OR REPLACE PROCEDURE IT.PRL_CAN_PLANILLA
 IS
   /************************************************************/
   /*	 Nombre: PRL_CANC_PLANILLA                               */
   /*	 Hecho Por: Lic. Julio Cesar Leguizamon G.               */
   /*	 Fecha: 23/11/2006                                       */
   /*	 Objetivo: Cancelar contablemente los resultados de la   */
	 /*  planilla de posicion de cambios                         */
	 /*  la cancelacion se realiza por el total equivalente del  */
   /*  dia	anterior y el ingreso por el total equivalente dia */
   /************************************************************/

    rv_gcale 						 	 ge_calendarios%rowtype;
    v_fcanter 						 ge_calendarios.fec_anterior%type;
    v_pos_anterior         ge_movimientos.mto_equ_local%type;
    v_pos_actual           ge_movimientos.mto_equ_local%type;
    v_hora 								 ge_movimientos.hora%type;
		v_secuencia 					 number(4) := 1;
    r_gmovi 							 ge_movimientos%rowtype;
    v_fcdehoy 						 date;
    v_cod_modalidad				 ge_movimientos.cod_modalidad%type;
    v_cod_mad_padre				 ge_movimientos.cod_mad_padre%type;
    v_redondeo_ml number(2) := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',7,null,pag_gen.fu_obt_mon_local);
		
/******************************************************************************/
--BLOQUE PRINCIPAL
/******************************************************************************/
BEGIN
    v_fcdehoy := pag_cal.fu_obt_fec_actual(7);
    rv_gcale  := pag_cal.fu_obt_reg_cal(7);
    v_fcanter := rv_gcale.fec_anterior;
			
    --Resuperar los montos de la posición anterior para cancelar
    begin
        select monto*-1, cod_modalidad, cod_mad_padre
        into v_pos_anterior, v_cod_modalidad, v_cod_mad_padre
        from lc_movimientos_his
				where fecha = v_fcanter
        and concepto = 'Ingreso Posicion Actual';
    exception
        when no_data_found then
				v_pos_anterior := 0;
        when others then
        raise_application_error(-20000,'Error al intentar recuperar posición anterior para cancelar');
    end;
		
		--Genero movimiento solo si es distinto a cero
		if v_pos_anterior <> 0 then
        --inicializa hora para los movimientos
        v_hora    := fug_ini_hora(sysdate, 'HH24:MI:SS');

        r_gmovi.cod_modulo      := 7;
        r_gmovi.cod_oficina     := 1;
        r_gmovi.nro_cuenta      := null;
        r_gmovi.cod_moneda      := 'GS';
        r_gmovi.cod_usuario     := user;
        r_gmovi.hora            := v_hora;
        r_gmovi.fecha           := v_fcdehoy;
        --
        r_gmovi.fec_valor       := v_fcdehoy;
        r_gmovi.cod_mod_padre   := 7;

        r_gmovi.cod_modalidad   := v_cod_modalidad;
        r_gmovi.cod_mad_padre   := v_cod_mad_padre;

        r_gmovi.nro_documento   := null;
        r_gmovi.nro_documento2  := null;
        r_gmovi.nro_documento3  := null;
        r_gmovi.cod_tasa        := null;
        r_gmovi.val_tasa        := null;
        r_gmovi.cotizacion      := null;
        r_gmovi.cod_ofi_origen  := 1;
        r_gmovi.emi_aviso       := 'N';
        r_gmovi.estado          := 'N';
        r_gmovi.reversado       := 'N';
				--
        r_gmovi.nro_secuencia   := v_secuencia;
        r_gmovi.cod_tra_padre   := 188;
        r_gmovi.cod_transaccion := 188;
        r_gmovi.monto           := v_pos_anterior ;
        r_gmovi.concepto        := 'Cancelacion Posicion Anterior';
        r_gmovi.referencia      := 'CONT.POSICI';
        pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
        v_secuencia := v_secuencia + 1;
		end if;

    --Resuperar los montos de la posición actual para ingresar
    begin
        select round(sum((b.monto+nvl((a.tot_compra-a.tot_venta),0))*(fug_obt_cotizacion(nvl(a.cod_moneda,b.cod_moneda) , v_fcdehoy))),v_redondeo_ml)
    		into v_pos_actual
        from lc_saldos_res a, (select cod_moneda, tip_posicion, mto_nef_compra-mto_nef_venta monto
                              from lc_sal_posiciones b
                              where tip_posicion = 'O'
                              union all
                              select cod_moneda, tip_posicion, mto_efe_compra-mto_efe_venta monto
                              from lc_sal_posiciones b
                              where tip_posicion = 'E') b
        where a.fecha(+) = v_fcdehoy
        and a.cod_moneda(+) = b.cod_moneda
        and a.tipo(+) = b.tip_posicion;
    exception
        when no_data_found then
				v_pos_actual := 0;
        when others then
        raise_application_error(-20000,'Error al intentar recuperar posición actual para ingresar');
    end;
		
		if nvl(v_pos_actual,0) <> 0 then		
        --inicializa hora para los movimientos
        v_hora    := fug_ini_hora(sysdate, 'HH24:MI:SS');
        r_gmovi.cod_modulo      := 7;
        r_gmovi.cod_oficina     := 1;
        r_gmovi.nro_cuenta      := null;
        r_gmovi.cod_moneda      := 'GS';
        r_gmovi.cod_usuario     := user;
        r_gmovi.hora            := v_hora;
        r_gmovi.fecha           := v_fcdehoy;
        --
        r_gmovi.fec_valor       := v_fcdehoy;
        r_gmovi.cod_mod_padre   := 7;
				if v_pos_actual > 0 then
          r_gmovi.cod_modalidad   := 71;
          r_gmovi.cod_mad_padre   := 71;
				else
          r_gmovi.cod_modalidad   := 72;
          r_gmovi.cod_mad_padre   := 72;
				end if;
        r_gmovi.nro_documento   := null;
        r_gmovi.nro_documento2  := null;
        r_gmovi.nro_documento3  := null;
        r_gmovi.cod_tasa        := null;
        r_gmovi.val_tasa        := null;
        r_gmovi.cotizacion      := null;
        r_gmovi.cod_ofi_origen  := 1;
        r_gmovi.emi_aviso       := 'N';
        r_gmovi.estado          := 'N';
        r_gmovi.reversado       := 'N';
        --
        r_gmovi.nro_secuencia   := v_secuencia;
        r_gmovi.cod_tra_padre   := 188;
        r_gmovi.cod_transaccion := 188;
        r_gmovi.monto           := abs(v_pos_actual) ;
        r_gmovi.concepto        := 'Ingreso Posicion Actual';
        r_gmovi.referencia      := 'CONT.POSICI';
        pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
    end if;
END;
/

