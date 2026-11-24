CREATE OR REPLACE PROCEDURE IT.PRK_GEN_MOV_IVA (
  p_fec_compra        in af_bienes.fec_compra%type,
  p_cod_ent_proveedor in af_bienes.cod_ent_proveedor%type,
  p_tipo              in af_bienes.tipo%type,
  p_nro_factura       in af_bienes.nro_factura%type,
  p_cantidad          in number,
  p_cod_oficina       in af_bienes.cod_oficina%type,
  p_cod_area          in af_bienes.cod_area%type,
  p_val_compra        in af_bienes.val_compra%type,
  p_cod_moneda        in af_bienes.cod_moneda%type,
  p_descripcion       in af_bienes.descripcion%type,
  p_hora              in ge_movimientos.hora%type default null,
  p_nro_secuencia     in out ge_movimientos.nro_secuencia%type,
  p_cod_modulo        in number,
  p_cod_modalidad     in number,
  p_cod_transaccion   in number,
  p_nro_linea         in number,
  p_cod_ofi_origen    in number,
  p_tip_impuesto      in number,
  p_val_impuesto      in pv_compras_det.val_impuesto%type,
  p_tra_iva           in pv_compras_det.transaccion_iva%type)
is
  -- Datos para generar el movimiento
  v_fec_actual        date         := pag_cal.fu_obt_fec_actual(13); -- fecha de hoy
  v_hor_actual        varchar2(08); -- Hora actual
  v_cod_usuario       varchar2(10) := upper(user);                   -- usuario
  v_nro_secuencia     number(3);                             -- secuencia del mov.
  r_gmovi             ge_movimientos%rowtype;
  ---
  v_impuesto          number(18,2);
  v_val_compra        af_bienes.val_compra%type;
  v_val_unitario      af_bienes.val_compra%type;
  ---

  cursor cur_trx_det is
  select 13 cod_modulo, 131 cod_modalidad, p_tra_iva cod_tra_hijo,
         13 cod_mod_hijo, 131 cod_mad_hijo
  from   dual
  where nvl(p_val_impuesto,0) <> 0;
begin
  --- Obtengo el maximo nro. de secuencia
  --- para evitar error de PK en GE_MOVIMIENTOS
  ---
  v_hor_actual := nvl(p_hora, to_char(sysdate,'HH24:MI:SS'));
  v_nro_secuencia := nvl(p_nro_secuencia,0);
   ---
   ---------------------------
   --- INSERTAR MOVIMIENTO ---
   ---------------------------
   --- IVA
/*   for r_trx_det in cur_trx_det loop
      v_impuesto               := 0;
      ---
		v_impuesto := p_val_impuesto;
      ---
      if v_impuesto > 0 then
          -- Aumento la secuencia
          if v_nro_secuencia  = 999 then
             v_hor_actual    := pag_gen.fu_obt_sig_segundo(v_hor_actual);
             v_nro_secuencia := 0;
          end if;
          v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
          -- Genero el movimiento
          r_gmovi.cod_modulo      := r_trx_det.cod_mod_hijo;
          r_gmovi.cod_modalidad   := r_trx_det.cod_mad_hijo;
          r_gmovi.cod_oficina     := p_cod_oficina;
          r_gmovi.nro_cuenta      := null;
          r_gmovi.cod_moneda      := p_cod_moneda;
          r_gmovi.cod_usuario     := v_cod_usuario;
          r_gmovi.hora            := v_hor_actual;
          r_gmovi.fecha           := v_fec_actual;
          r_gmovi.nro_secuencia   := v_nro_secuencia;
          --
          r_gmovi.fec_valor       := v_fec_actual;
          r_gmovi.cod_tra_padre   := r_trx_det.cod_tra_hijo;
          r_gmovi.cod_mod_padre   := r_trx_det.cod_modulo;
          r_gmovi.cod_mad_padre   := r_trx_det.cod_modalidad;
          r_gmovi.cod_transaccion := r_trx_det.cod_tra_hijo;
          r_gmovi.monto           := nvl(v_impuesto,0);
          r_gmovi.nro_documento   := p_nro_linea;
          r_gmovi.cod_tasa        := null;
          r_gmovi.val_tasa        := null;
          r_gmovi.cotizacion      := null;
          if fug_obt_tip_implementacion = 1 then
             r_gmovi.cod_ofi_origen  := p_cod_ofi_origen;
          else
             r_gmovi.cod_ofi_origen  := 1;
          end if;
          r_gmovi.emi_aviso       := 'N';
          r_gmovi.concepto        := substr('IVA s/'||p_descripcion,1,35);
          r_gmovi.estado          := 'N';
          r_gmovi.reversado       := 'N';
          r_gmovi.nro_caja        := null;
          r_gmovi.cod_rubro       := NULL;
          PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, 'N'); -- no es nocturno
      end if;
      exit;
   end loop;*/
	v_impuesto               := 0;
	---
	v_impuesto := p_val_impuesto;
	---
	if v_impuesto > 0 then
	-- Aumento la secuencia
	if v_nro_secuencia  = 999 then
	 v_hor_actual    := pag_gen.fu_obt_sig_segundo(v_hor_actual);
	 v_nro_secuencia := 0;
	end if;
	v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
	-- Genero el movimiento
	r_gmovi.cod_modulo      := p_cod_modulo;
	r_gmovi.cod_modalidad   := p_cod_modalidad;
	r_gmovi.cod_oficina     := p_cod_oficina;
	r_gmovi.nro_cuenta      := null;
	r_gmovi.cod_moneda      := p_cod_moneda;
	r_gmovi.cod_usuario     := v_cod_usuario;
	r_gmovi.hora            := v_hor_actual;
	r_gmovi.fecha           := v_fec_actual;
	r_gmovi.nro_secuencia   := v_nro_secuencia;
	--
	r_gmovi.fec_valor       := v_fec_actual;
	r_gmovi.cod_tra_padre   := p_cod_transaccion;
	r_gmovi.cod_mod_padre   := p_cod_modulo;
	r_gmovi.cod_mad_padre   := p_cod_modalidad;
	r_gmovi.cod_transaccion := p_cod_transaccion;
	r_gmovi.monto           := nvl(v_impuesto,0);
	r_gmovi.nro_documento   := p_nro_linea;
	r_gmovi.cod_tasa        := null;
	r_gmovi.val_tasa        := null;
	r_gmovi.cotizacion      := null;
	if fug_obt_tip_implementacion = 1 then
	 r_gmovi.cod_ofi_origen  := p_cod_ofi_origen;
	else
	 r_gmovi.cod_ofi_origen  := 1;
	end if;
	r_gmovi.emi_aviso       := 'N';
	r_gmovi.concepto        := substr('IVA s/'||p_descripcion,1,35);
	r_gmovi.estado          := 'N';
	r_gmovi.reversado       := 'N';
	r_gmovi.nro_caja        := null;
	r_gmovi.cod_rubro       := NULL;
	PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, 'N'); -- no es nocturno
	end if;

	p_nro_secuencia := v_nro_secuencia;
end;
/

