CREATE OR REPLACE PROCEDURE IT.PRF_BAJ_ACT_FIJO (
   p_cod_bien af_bienes.cod_bien%type,
   p_fec_baja af_bienes.fec_enajenacion%type,
   p_tip_baja af_bienes.estado%type)
is
  -- Datos para generar el movimiento
  v_fec_actual        date         := pag_cal.fu_obt_fec_actual(13); -- fecha de hoy
  v_hor_actual        varchar2(08) := to_char(sysdate,'HH24:MI:SS'); -- Hora actual
  v_cod_usuario       varchar2(10) := upper(user);                   -- usuario
  v_nro_secuencia     number(3)    := 0;                             -- secuencia del mov.
  r_bien              af_bienes%rowtype;
  r_tip_baja          af_tip_movimientos%rowtype;
  r_gmovi             ge_movimientos%rowtype;
  r_articulo          af_articulos%rowtype;
  v_dep_acumulada     af_bienes.dep_acumulada%type;
  v_revaluo           af_bienes.rev_depreciacion%type;
  --
begin
  if nvl(p_cod_bien,0) = 0 then
     raise_application_error(-20000,'Error al obtener el codigo del bien');
  end if;
  ---
  if nvl(p_tip_baja,'A') = 'A' then
     raise_application_error(-20000,'Debe ingresar un nuevo estado para el bien');
  end if;
  ---
  if p_fec_baja is null then
     raise_application_error(-20000,'Debe ingresar la fecha de baja');
  end if;
  --- Actualizo el bien
  update af_bienes
  set    fec_enajenacion  = p_fec_baja,
         estado           = p_tip_baja
  where  cod_bien         = p_cod_bien;
  ---
  PRF_OBT_BIEN(p_cod_bien, r_bien);
  PRF_OBT_ARTICULO(r_bien.cod_articulo,r_articulo);
  ---
  ---------------------------
  --- INSERTAR MOVIMIENTO ---
  ---------------------------
  ---
  --- Depreciacion Acumulada
  ---
  v_hor_actual            := pag_gen.fu_obt_sig_segundo(v_hor_actual);
  -- Aumento la secuencia
  v_nro_secuencia         := nvl(v_nro_secuencia,0) + 1;
  ---
  v_dep_acumulada := nvl(r_bien.dep_acumulada,0);
  ---
  -- Genero el movimiento
  if nvl(v_dep_acumulada,0) != 0 then
     r_gmovi.cod_modulo      := r_articulo.cod_modulo;
     r_gmovi.cod_modalidad   := r_articulo.cod_modalidad;
     r_gmovi.cod_oficina     := r_bien.cod_oficina;
     r_gmovi.nro_cuenta      := null;
     r_gmovi.cod_moneda      := r_bien.cod_moneda;
     r_gmovi.cod_usuario     := v_cod_usuario;
     r_gmovi.hora            := v_hor_actual;
     r_gmovi.fecha           := v_fec_actual;
     r_gmovi.nro_secuencia   := v_nro_secuencia;
     --
     r_gmovi.fec_valor       := v_fec_actual;
     r_gmovi.cod_tra_padre   := 1300;
     r_gmovi.cod_mod_padre   := r_articulo.cod_modulo;
     r_gmovi.cod_mad_padre   := r_articulo.cod_modalidad;
     r_gmovi.cod_transaccion := r_articulo.cod_tra_dep_baja;
     r_gmovi.monto           := v_dep_acumulada;
     r_gmovi.nro_documento   := r_bien.cod_bien;
     r_gmovi.cod_tasa        := null;
     r_gmovi.val_tasa        := null;
     r_gmovi.cotizacion      := null;
     r_gmovi.cod_ofi_origen  := r_bien.cod_oficina;
     r_gmovi.emi_aviso       := 'N';
     r_gmovi.concepto        := substr(r_bien.descripcion,1,35);
     r_gmovi.estado          := 'N';
     r_gmovi.reversado       := 'N';
     r_gmovi.nro_caja        := null;
     r_gmovi.cod_rubro       := NULL;
     r_gmovi.tip_mov_rubro   := 'D';--DEBITO
     PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, 'N'); -- no es nocturno
  end if;
  --- Valor costo revaluo
  ---
  v_hor_actual            := pag_gen.fu_obt_sig_segundo(v_hor_actual);
  -- Aumento la secuencia
  v_nro_secuencia         := nvl(v_nro_secuencia,0) + 1;
  ---
  if nvl(r_bien.rev_actual,0) = 0 then
     v_revaluo := r_bien.val_compra;
  else
     v_revaluo := r_bien.rev_actual;
  end if;
  ---
  -- Genero el movimiento
  r_gmovi.cod_modulo      := r_articulo.cod_modulo;
  r_gmovi.cod_modalidad   := r_articulo.cod_modalidad;
  r_gmovi.cod_oficina     := r_bien.cod_oficina;
  r_gmovi.nro_cuenta      := null;
  r_gmovi.cod_moneda      := r_bien.cod_moneda;
  r_gmovi.cod_usuario     := v_cod_usuario;
  r_gmovi.hora            := v_hor_actual;
  r_gmovi.fecha           := v_fec_actual;
  r_gmovi.nro_secuencia   := v_nro_secuencia;
  --
  r_gmovi.fec_valor       := v_fec_actual;
  r_gmovi.cod_tra_padre   := 1300;
  r_gmovi.cod_mod_padre   := r_articulo.cod_modulo;
  r_gmovi.cod_mad_padre   := r_articulo.cod_modalidad;
  r_gmovi.cod_transaccion := r_articulo.cod_tra_rev_baja;
  r_gmovi.monto           := v_revaluo;
  r_gmovi.nro_documento   := r_bien.cod_bien;
  r_gmovi.cod_tasa        := null;
  r_gmovi.val_tasa        := null;
  r_gmovi.cotizacion      := null;
  r_gmovi.cod_ofi_origen  := r_bien.cod_oficina;
  r_gmovi.emi_aviso       := 'N';
  r_gmovi.concepto        := substr(r_bien.descripcion,1,35);
  r_gmovi.estado          := 'N';
  r_gmovi.reversado       := 'N';
  r_gmovi.nro_caja        := null;
  r_gmovi.cod_rubro       := NULL;
  r_gmovi.tip_mov_rubro   := 'C';--CREDITO
  PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, 'N'); -- no es nocturno
  ---
  --- Cuenta generica del tipo de Baja
  ---
  PRF_OBT_TIP_MOVIMIENTO('B',p_tip_baja, r_tip_baja);
  ---
  v_hor_actual            := pag_gen.fu_obt_sig_segundo(v_hor_actual);
  -- Aumento la secuencia
  v_nro_secuencia         := nvl(v_nro_secuencia,0) + 1;
  -- Genero el movimiento
  r_gmovi.cod_modulo      := r_tip_baja.cod_modulo;
  r_gmovi.cod_modalidad   := r_tip_baja.cod_modalidad;
  r_gmovi.cod_oficina     := r_bien.cod_oficina;
  r_gmovi.nro_cuenta      := null;
  r_gmovi.cod_moneda      := r_bien.cod_moneda;
  r_gmovi.cod_usuario     := v_cod_usuario;
  r_gmovi.hora            := v_hor_actual;
  r_gmovi.fecha           := v_fec_actual;
  r_gmovi.nro_secuencia   := v_nro_secuencia;
  --
  r_gmovi.fec_valor       := v_fec_actual;
  r_gmovi.cod_tra_padre   := 1300;
  r_gmovi.cod_mod_padre   := r_tip_baja.cod_modulo;
  r_gmovi.cod_mad_padre   := r_tip_baja.cod_modalidad;
  r_gmovi.cod_transaccion := r_tip_baja.cod_transaccion;
  r_gmovi.monto           := nvl(v_revaluo,0) - nvl(v_dep_acumulada,0);
  r_gmovi.nro_documento   := r_bien.cod_bien;
  r_gmovi.cod_tasa        := null;
  r_gmovi.val_tasa        := null;
  r_gmovi.cotizacion      := null;
  r_gmovi.cod_ofi_origen  := r_bien.cod_oficina;
  r_gmovi.emi_aviso       := 'N';
  r_gmovi.concepto        := substr(r_bien.descripcion,1,35);
  r_gmovi.estado          := 'N';
  r_gmovi.reversado       := 'N';
  r_gmovi.nro_caja        := null;
  r_gmovi.cod_rubro       := NULL;
  r_gmovi.tip_mov_rubro   := 'D';--DEBITO
  PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, 'N'); -- no es nocturno
  ---
end;
/

