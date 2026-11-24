CREATE OR REPLACE PROCEDURE IT.PRF_VEN_ACT_FIJO(p_cod_bien  af_bienes.cod_bien%type,
                                             p_fec_baja  af_bienes.fec_enajenacion%type,
                                             p_val_venta af_bienes.val_neto%type,
                                             p_tip_venta af_tip_movimientos.cod_movimiento%type)
 is
	-- Datos para generar el movimiento
	v_fec_actual    date := pag_cal.fu_obt_fec_actual(13); -- fecha de hoy
	v_hor_actual    varchar2(08) := to_char(sysdate, 'HH24:MI:SS'); -- Hora actual
	v_cod_usuario   varchar2(10) := upper(user); -- usuario
	v_nro_secuencia number(3) := 0; -- secuencia del mov.
	r_bien          af_bienes%rowtype;
	r_tip_venta     af_tip_movimientos%rowtype;
	r_gmovi         ge_movimientos%rowtype;
	r_articulo      af_articulos%rowtype;
	v_val_compra    af_bienes.val_compra%type;
	v_tip_mov       varchar2(1);
	v_mto_venta     number;
	---
	cursor cur_trx_det is
	select *
	from   ge_transacciones_det
	where  cod_modulo = 13
	and    cod_modalidad = 131
	and    cod_transaccion = r_tip_venta.cod_transaccion;

begin
	v_hor_actual := pag_gen.fu_obt_sig_segundo(v_hor_actual);

	if nvl(p_cod_bien, 0) = 0 then
	raise_application_error(-20000, 'Error al obtener el codigo del bien');
	end if;

	if p_fec_baja is null then
	raise_application_error(-20000, 'Debe ingresar la fecha de baja');
	end if;

	if nvl(p_val_venta, 0) = 0 then
	raise_application_error(-20000, 'Debe ingresar el valor de la venta');
	end if;

	if nvl(p_tip_venta,'A') = 'A' then
	raise_application_error(-20000,'Debe ingresar un nuevo estado para el bien');
	end if;

	PRF_OBT_BIEN(p_cod_bien, r_bien);
	PRF_OBT_ARTICULO(r_bien.cod_articulo, r_articulo);


	/*******************************************************************************/
	--- Depreciacion Acumulada
	/*******************************************************************************/
	v_nro_secuencia := nvl(v_nro_secuencia, 0) + 1;
	-- Genero el movimiento
	r_gmovi.cod_modulo    := r_articulo.cod_modulo;
	r_gmovi.cod_modalidad := r_articulo.cod_modalidad;
	r_gmovi.cod_oficina   := r_bien.cod_oficina;
	r_gmovi.nro_cuenta    := null;
	r_gmovi.cod_moneda    := r_bien.cod_moneda;
	r_gmovi.cod_usuario   := v_cod_usuario;
	r_gmovi.hora          := v_hor_actual;
	r_gmovi.fecha         := v_fec_actual;
	r_gmovi.nro_secuencia := v_nro_secuencia;
	r_gmovi.fec_valor       := v_fec_actual;
	r_gmovi.cod_tra_padre   := 1300;
	r_gmovi.cod_mod_padre   := r_articulo.cod_modulo;
	r_gmovi.cod_mad_padre   := r_articulo.cod_modalidad;
	r_gmovi.cod_transaccion := r_articulo.cod_tra_dep_baja;
	r_gmovi.monto           := nvl(r_bien.dep_acumulada,0);
	r_gmovi.nro_documento   := r_bien.cod_bien;
	r_gmovi.cod_tasa        := null;
	r_gmovi.val_tasa        := null;
	r_gmovi.cotizacion      := null;
	r_gmovi.cod_ofi_origen  := 1;
	r_gmovi.emi_aviso       := 'N';
	r_gmovi.concepto        := substr(r_bien.descripcion,1,35);
	r_gmovi.estado          := 'N';
	r_gmovi.reversado       := 'N';
	r_gmovi.nro_caja        := null;
	r_gmovi.cod_rubro       := NULL;
	r_gmovi.tip_mov_rubro   := 'D'; --DEBITO
	PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, 'N'); -- no es nocturno

	/*******************************************************************************/
	--- Valor costo revaluo
	/*******************************************************************************/
	if nvl(r_bien.rev_actual,0) = 0 then
		v_val_compra := r_bien.val_compra;
	else
		v_val_compra := r_bien.rev_actual;
	end if;

	v_nro_secuencia := nvl(v_nro_secuencia, 0) + 1;
	-- Genero el movimiento
	r_gmovi.cod_modulo    := r_articulo.cod_modulo;
	r_gmovi.cod_modalidad := r_articulo.cod_modalidad;
	r_gmovi.cod_oficina   := r_bien.cod_oficina;
	r_gmovi.nro_cuenta    := null;
	r_gmovi.cod_moneda    := r_bien.cod_moneda;
	r_gmovi.cod_usuario   := v_cod_usuario;
	r_gmovi.hora          := v_hor_actual;
	r_gmovi.fecha         := v_fec_actual;
	r_gmovi.nro_secuencia := v_nro_secuencia;
	r_gmovi.fec_valor       := v_fec_actual;
	r_gmovi.cod_tra_padre   := 1300;
	r_gmovi.cod_mod_padre   := r_articulo.cod_modulo;
	r_gmovi.cod_mad_padre   := r_articulo.cod_modalidad;
	r_gmovi.cod_transaccion := r_articulo.cod_tra_rev_baja;
	r_gmovi.monto           := nvl(v_val_compra,0);
	r_gmovi.nro_documento   := r_bien.cod_bien;
	r_gmovi.cod_tasa        := null;
	r_gmovi.val_tasa        := null;
	r_gmovi.cotizacion      := null;
	r_gmovi.cod_ofi_origen  := 1;
	r_gmovi.emi_aviso       := 'N';
	r_gmovi.concepto        := substr(r_bien.descripcion,1,35);
	r_gmovi.estado          := 'N';
	r_gmovi.reversado       := 'N';
	r_gmovi.nro_caja        := null;
	r_gmovi.cod_rubro       := NULL;
	r_gmovi.tip_mov_rubro   := 'C'; --CREDITO
	PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, 'N'); -- no es nocturno

	/*******************************************************************************/
	--- Cuenta generica del tipo de Venta
	/*******************************************************************************/
	PRF_OBT_TIP_MOVIMIENTO('V', p_tip_venta, r_tip_venta);

	v_nro_secuencia := nvl(v_nro_secuencia, 0) + 1;
	-- Genero el movimiento
	v_tip_mov := fug_obt_tip_mov_contable(13,131,r_tip_venta.cod_transaccion);
	v_mto_venta := nvl(p_val_venta,0) - nvl(r_bien.val_neto,0);
	-- si el monto es negativo se multiplica por -1
	-- para que al generar el asiento no cambie de tipo de movimiento
	if v_mto_venta < 0 then
		v_mto_venta := v_mto_venta * -1;
	end if;
	r_gmovi.cod_modulo    := r_tip_venta.cod_modulo;
	r_gmovi.cod_modalidad := r_tip_venta.cod_modalidad;
	r_gmovi.cod_oficina   := r_bien.cod_oficina;
	r_gmovi.nro_cuenta    := null;
	r_gmovi.cod_moneda    := r_bien.cod_moneda;
	r_gmovi.cod_usuario   := v_cod_usuario;
	r_gmovi.hora          := v_hor_actual;
	r_gmovi.fecha         := v_fec_actual;
	r_gmovi.nro_secuencia := v_nro_secuencia;
	r_gmovi.fec_valor       := v_fec_actual;
	r_gmovi.cod_tra_padre   := 1300;
	r_gmovi.cod_mod_padre   := r_tip_venta.cod_modulo;
	r_gmovi.cod_mad_padre   := r_tip_venta.cod_modalidad;
	r_gmovi.cod_transaccion := r_tip_venta.cod_transaccion;
	r_gmovi.monto           := nvl(v_mto_venta,0);
	r_gmovi.nro_documento   := r_bien.cod_bien;
	r_gmovi.cod_tasa        := null;
	r_gmovi.val_tasa        := null;
	r_gmovi.cotizacion      := null;
	r_gmovi.cod_ofi_origen  := 1;
	r_gmovi.emi_aviso       := 'N';
	r_gmovi.concepto        := substr(r_bien.descripcion,1,35);
	r_gmovi.estado          := 'N';
	r_gmovi.reversado       := 'N';
	r_gmovi.nro_caja        := null;
	r_gmovi.cod_rubro       := NULL;
	r_gmovi.tip_mov_rubro   := v_tip_mov;
	PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, 'N'); -- no es nocturno

	/*******************************************************************************/
	--- Cuenta transitoria de Venta
	/*******************************************************************************/
	for r_trx_det in cur_trx_det loop
		--v_hor_actual            := pag_gen.fu_obt_sig_segundo(v_hor_actual);
		v_nro_secuencia         := nvl(v_nro_secuencia,0) + 1;
		-- Genero el movimiento
		v_tip_mov := fug_obt_tip_mov_contable(13,131,r_trx_det.cod_tra_hijo);
		--
		r_gmovi.cod_modulo      := r_trx_det.cod_mod_hijo;
		r_gmovi.cod_modalidad   := r_trx_det.cod_mad_hijo;
		r_gmovi.cod_oficina     := r_bien.cod_oficina;
		r_gmovi.nro_cuenta      := null;
		r_gmovi.cod_moneda      := r_bien.cod_moneda;
		r_gmovi.cod_usuario     := v_cod_usuario;
		r_gmovi.hora            := v_hor_actual;
		r_gmovi.fecha           := v_fec_actual;
		r_gmovi.nro_secuencia   := v_nro_secuencia;
		r_gmovi.fec_valor       := v_fec_actual;
		r_gmovi.cod_tra_padre   := 1300;
		r_gmovi.cod_mod_padre   := r_trx_det.cod_modulo;
		r_gmovi.cod_mad_padre   := r_trx_det.cod_modalidad;
		r_gmovi.cod_transaccion := r_trx_det.cod_tra_hijo;
		r_gmovi.monto           := p_val_venta;
		r_gmovi.nro_documento   := r_bien.cod_bien;
		r_gmovi.cod_tasa        := null;
		r_gmovi.val_tasa        := null;
		r_gmovi.cotizacion      := null;
		r_gmovi.cod_ofi_origen  := 1;
		r_gmovi.emi_aviso       := 'N';
		r_gmovi.concepto        := substr(r_bien.descripcion,1,35);
		r_gmovi.estado          := 'N';
		r_gmovi.reversado       := 'N';
		r_gmovi.nro_caja        := null;
		r_gmovi.cod_rubro       := NULL;
		r_gmovi.tip_mov_rubro   := v_tip_mov;
		PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, 'N'); -- no es nocturno
	end loop;

	--- Actualizo el bien
	update af_bienes
	set fec_enajenacion = p_fec_baja,
	estado          = p_tip_venta
	where cod_bien        = p_cod_bien;

end;
/

