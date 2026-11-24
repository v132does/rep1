CREATE OR REPLACE PROCEDURE IT.PRF_GEN_BIEN (
  p_fec_compra        in af_bienes.fec_compra%type,
  p_cod_ent_proveedor in af_bienes.cod_ent_proveedor%type,
  p_tipo              in af_bienes.tipo%type,
  p_nro_factura       in af_bienes.nro_factura%type,
  p_cantidad          in number,
  p_cod_articulo      in af_bienes.cod_articulo%type,
  p_cod_oficina       in af_bienes.cod_oficina%type,
  p_cod_area          in af_bienes.cod_area%type,
  p_val_compra        in af_bienes.val_compra%type,
  p_val_neto          in af_bienes.val_compra%type,
  p_val_impuesto      in af_bienes.val_compra%type,
  p_cod_moneda        in af_bienes.cod_moneda%type,
  p_descripcion       in af_bienes.descripcion%type,
  p_tra_iva           in ge_transacciones.cod_transaccion%type,
  p_hora              in ge_movimientos.hora%type default null,
  p_nro_secuencia     in out ge_movimientos.nro_secuencia%type,
  p_tip_venta         in pv_compras.tip_venta%type,
  p_cod_compra        in pv_compras.cod_compra%type,
  P_COD_MOD_PADRE     in ge_movimientos.cod_mod_padre%type  DEFAULT NULL,    -- /*09/12/2013 PN DI: Cod de módulo padre del movimiento de la factura*/
  P_COD_MAD_PADRE     in ge_movimientos.cod_mad_padre%type  DEFAULT NULL,    -- /*09/12/2013 PN DI: Cod de modalidad padre del movimiento de la factura*/
  P_COD_TRA_PADRE     in ge_movimientos.cod_tra_padre%type  DEFAULT NULL)    -- /*09/12/2013 PN DI: Cod de transaccion padre del movimiento de la factura*/

is
  -- Datos para generar el movimiento
  v_fec_actual        date         := pag_cal.fu_obt_fec_actual(13); -- fecha de hoy
  v_hor_actual        varchar2(08) := to_char(sysdate,'HH24:MI:SS'); -- Hora actual
  v_cod_usuario       varchar2(10) := upper(user);                   -- usuario
  v_nro_secuencia     number(3)    := 0;                             -- secuencia del mov.
  r_bien              AF_BIENES%ROWTYPE;
  r_articulo          af_articulos%rowtype;
  r_gmovi             ge_movimientos%rowtype;
  r_tip_alta          af_tip_movimientos%rowtype;
  r_sumi              in_suministros%rowtype;
  ---
  v_tasa              number(18,2);
  v_impuesto          number(18,2);
  v_acu_impuesto      number(18,2);
  v_val_compra        af_bienes.val_compra%type;
  v_val_unitario      af_bienes.val_compra%type;
  v_ofi_suministro    ba_oficinas.cod_oficina%type := FUG_OBT_PARDINAMICO('OFI_SUMINISTRO');
  v_area_suministro   ba_areas.cod_area%type := FUG_OBT_PARDINAMICO('AREA_SUMINISTRO');
  v_ind_suministro    af_articulos.ind_suministro%type;
  ---
  v_cod_mon_local  ba_monedas.cod_moneda%type;
  v_cotizacion      ge_cotizaciones.val_conversion%type;
  v_redondeo        NUMBER(5);
begin
  --- Obtengo el maximo nro. de secuencia
  --- para evitar error de PK en GE_MOVIMIENTOS
  ---
  v_hor_actual := nvl(p_hora, to_char(sysdate,'HH24:MI:SS'));
  v_nro_secuencia := nvl(p_nro_secuencia,0);
  v_cod_mon_local := pag_gen.FU_OBT_MON_LOCAL;
  v_redondeo      := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',null,null,v_cod_mon_local);
  v_cotizacion := nvl(pag_gen.fu_obt_cotizacion( p_cod_moneda, v_fec_actual),1);--AP 2870 29-05-2012 V.V.
  ---
  for i in 1 .. p_cantidad loop
    v_acu_impuesto := 0;
    --- Obtener Artículo
    PRF_OBT_ARTICULO(p_cod_articulo,r_articulo);
    ---
    select s_cod_bien.nextval
    into   r_bien.cod_bien
    from   dual;
    ---

    if i = p_cantidad then
       v_val_unitario :=  nvl(pag_gen.FU_CON_MON_A_MONEDA(p_cod_moneda, v_cod_mon_local, nvl(p_val_neto,0), pag_gen.FU_OBT_COTIZACION(p_cod_moneda,v_fec_actual)),0) - NVL(v_val_compra,0);
    else
       v_val_unitario := floor(nvl(pag_gen.FU_CON_MON_A_MONEDA(p_cod_moneda, v_cod_mon_local, nvl(p_val_neto,0), pag_gen.FU_OBT_COTIZACION(p_cod_moneda,v_fec_actual)),0)/p_cantidad);
       v_val_compra   := nvl(v_val_compra,0) + nvl(v_val_unitario,0);
    end if;

    ---
    r_bien.fec_compra        := p_fec_compra;
    r_bien.cod_ent_proveedor := p_cod_ent_proveedor;
    r_bien.tipo              := p_tipo;
    r_bien.nro_factura       := p_nro_factura;
    r_bien.cod_articulo      := p_cod_articulo;
    r_bien.cod_oficina       := p_cod_oficina;
    r_bien.cod_area          := p_cod_area;
    r_bien.val_compra        := nvl(v_val_unitario,0);
    r_bien.cod_moneda        := v_cod_mon_local;
    r_bien.descripcion       := p_descripcion;
    r_bien.cod_compra        := p_cod_compra;
    --- Insertar el Bien si es Activo Fijo
    if nvl(r_articulo.ind_act_fijo,'N') = 'S' then
       prf_ins_bien(r_bien, p_tip_venta);
    end if;
    --- Insertar el Artículo si es Suministros
    if nvl(r_articulo.ind_suministro,'N') = 'S' then
       r_sumi.cod_suministro    := r_bien.cod_bien;
       r_sumi.fecha             := p_fec_compra;
       r_sumi.cod_ent_proveedor := p_cod_ent_proveedor;
       r_sumi.tipo              := p_tipo;
       r_sumi.nro_factura       := p_nro_factura;
       r_sumi.cod_articulo      := p_cod_articulo;
       r_sumi.cod_oficina       := p_cod_oficina;
       r_sumi.cod_area          := p_cod_area;
       r_sumi.val_compra        := nvl(v_val_unitario,0);
       r_sumi.cod_moneda        := v_cod_mon_local;
       r_sumi.descripcion       := p_descripcion;
     if (p_cod_oficina <> v_ofi_suministro or p_cod_area <> v_area_suministro) and r_articulo.cod_tip_articulo <> fug_obt_pardinamico ('TIP_ARTICULO') then
          r_sumi.estado            := 'T';
          r_sumi.fec_transferencia := v_fec_actual;
     else
          r_sumi.estado            := 'A';
          r_sumi.fec_transferencia := null;
     end if;

       PRZ_INS_SUMINISTRO (r_sumi);
    end if;
  end loop;

   ---------------------------
   --- INSERTAR MOVIMIENTO ---
   ---------------------------
   --- Revaluo

   If p_tip_venta = 'CR' and nvl(r_articulo.ind_act_fijo,'N') = 'S' then
   -- Aumento la secuencia
     if v_nro_secuencia  = 999 then
        v_hor_actual    := pag_gen.fu_obt_sig_segundo(v_hor_actual);
        v_nro_secuencia := 0;
     end if;
     v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
     -- Genero el movimiento
     r_gmovi.cod_modulo      := r_articulo.cod_modulo;
     r_gmovi.cod_modalidad   := r_articulo.cod_modalidad;
     r_gmovi.cod_oficina     := r_bien.cod_oficina;
     r_gmovi.nro_cuenta      := null;
     r_gmovi.cod_moneda      := p_cod_moneda;
     r_gmovi.cod_usuario     := v_cod_usuario;
     r_gmovi.hora            := v_hor_actual;
     r_gmovi.fecha           := v_fec_actual;
     r_gmovi.nro_secuencia   := v_nro_secuencia;
     --
     r_gmovi.fec_valor       := v_fec_actual;
     /*09/12/2013 PN DI: Se generan los movimientos en base a los parámetros de Transaccion Padre que recibe. 
                         De tal forma que tenga la misma transacción padre que la de su factura de Origen*/
     r_gmovi.cod_tra_padre   := nvl(p_cod_tra_padre,1300);
     r_gmovi.cod_mod_padre   := nvl(p_cod_mod_padre,r_articulo.cod_modulo);
     r_gmovi.cod_mad_padre   := nvl(p_cod_mad_padre,r_articulo.cod_modalidad);
     r_gmovi.cod_transaccion := r_articulo.cod_tra_alta; --null
     r_gmovi.monto           := p_val_compra;
     r_gmovi.nro_documento   := r_bien.cod_bien;
     r_gmovi.cod_tasa        := null;
     r_gmovi.val_tasa        := null;
     if p_cod_moneda <> v_cod_mon_local then
        r_gmovi.mto_equ_local   := round((p_val_compra * v_cotizacion),v_redondeo);
        r_gmovi.cotizacion      := v_cotizacion;
     else
        r_gmovi.mto_equ_local   := null;
        r_gmovi.cotizacion      := null;
     end if;
     if fug_obt_tip_implementacion = 1 then
        r_gmovi.cod_ofi_origen  := v_ofi_suministro;
     else
        r_gmovi.cod_ofi_origen  := 1;
     end if;
     r_gmovi.emi_aviso       := 'N';
     r_gmovi.concepto        := substr(r_bien.descripcion,1,30)||' $$$';--35
     r_gmovi.estado          := 'N';
     r_gmovi.reversado       := 'N';
     r_gmovi.nro_caja        := null;
     r_gmovi.cod_rubro       := null;--fug_obt_pardinamico('COD_RUB_CTA_SUSP_BIENES',null,null,p_cod_moneda,null);
     r_gmovi.tip_mov_rubro   := null;--'D';--DEBITO
     PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, 'N'); -- no es nocturno
   elsif p_tip_venta = 'CO' and nvl(r_articulo.ind_act_fijo,'N') = 'S' then
     -- Aumento la secuencia
     if v_nro_secuencia  = 999 then
        v_hor_actual    := pag_gen.fu_obt_sig_segundo(v_hor_actual);
        v_nro_secuencia := 0;
     end if;
     v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
     -- Genero el movimiento
     r_gmovi.cod_modulo      := r_articulo.cod_modulo;
     r_gmovi.cod_modalidad   := r_articulo.cod_modalidad;
     r_gmovi.cod_oficina     := r_bien.cod_oficina;
     r_gmovi.nro_cuenta      := null;
     r_gmovi.cod_moneda      := p_cod_moneda;
     r_gmovi.cod_usuario     := v_cod_usuario;
     r_gmovi.hora            := v_hor_actual;
     r_gmovi.fecha           := v_fec_actual;
     r_gmovi.nro_secuencia   := v_nro_secuencia;
     --
     r_gmovi.fec_valor       := v_fec_actual;
     r_gmovi.cod_tra_padre   := nvl(p_cod_tra_padre, 1300);
     r_gmovi.cod_mod_padre   := nvl(p_cod_mod_padre, r_articulo.cod_modulo);
     r_gmovi.cod_mad_padre   := nvl(p_cod_mad_padre, r_articulo.cod_modalidad);
     r_gmovi.cod_transaccion := r_articulo.cod_tra_alta;
     r_gmovi.monto           := p_val_compra;
     r_gmovi.nro_documento   := r_bien.cod_bien;
     r_gmovi.cod_tasa        := null;
     r_gmovi.val_tasa        := null;
     if p_cod_moneda <> v_cod_mon_local then
        r_gmovi.mto_equ_local   := round((p_val_compra * v_cotizacion),v_redondeo);
        r_gmovi.cotizacion      := v_cotizacion;
     else
        r_gmovi.mto_equ_local   := null;
        r_gmovi.cotizacion      := null;
     end if;
     if fug_obt_tip_implementacion = 1 then
        r_gmovi.cod_ofi_origen  := v_ofi_suministro;
     else
        r_gmovi.cod_ofi_origen  := 1;
     end if;
     r_gmovi.emi_aviso       := 'N';
     r_gmovi.concepto        := substr(r_bien.descripcion,1,30)||' ###';
     r_gmovi.estado          := 'N';
     r_gmovi.reversado       := 'N';
     r_gmovi.nro_caja        := null;
     r_gmovi.cod_rubro       := NULL;
     r_gmovi.tip_mov_rubro   := NULL;--DEBITO
     PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, 'N'); -- no es nocturno
   end if;
   ---
   --PRF_OBT_TIP_MOVIMIENTO('A','A', r_tip_alta);
   ---
  -- Para los casos que el articulo ingresa directo a la sucursal origen reliza la transferencia automatica
  -- La transferencia automatica se aplica solo a articulos de suministros JCLG 2008/08/26
  --------------------------------------
  --- MOVIMIENTOS OFICINA DE DESTINO ---
  --------------------------------------
  begin
    select ind_suministro
    into v_ind_suministro
    from af_articulos
    where cod_articulo = r_bien.cod_articulo;
  exception
  when others then
    raise_application_error(-20000,'Error al intentar recuperar datos de af_articulos'||sqlerrm);
  end;

  If  v_ind_suministro = 'S' then
      if v_nro_secuencia  = 999 then
        v_hor_actual    := pag_gen.fu_obt_sig_segundo(v_hor_actual);
        v_nro_secuencia := 0;
      end if;
      v_nro_secuencia         := nvl(v_nro_secuencia,0) + 1;
      r_gmovi.cod_modulo      := r_articulo.cod_modulo;
      r_gmovi.cod_modalidad   := r_articulo.cod_modalidad;
      r_gmovi.cod_oficina     := v_ofi_suministro;
      r_gmovi.nro_cuenta      := null;
      r_gmovi.cod_moneda      := p_cod_moneda;
      r_gmovi.cod_usuario     := v_cod_usuario;
      r_gmovi.hora            := v_hor_actual;
      r_gmovi.fecha           := v_fec_actual;
      r_gmovi.nro_secuencia   := v_nro_secuencia;
      --
      r_gmovi.fec_valor       := v_fec_actual;
      r_gmovi.cod_tra_padre   := nvl(p_cod_tra_padre,1300);
      r_gmovi.cod_mod_padre   := nvl(p_cod_mod_padre,r_articulo.cod_modulo);
      r_gmovi.cod_mad_padre   := nvl(p_cod_mad_padre,r_articulo.cod_modalidad);
      r_gmovi.cod_transaccion := r_articulo.cod_tra_alta;--r_articulo.cod_tra_rev_baja;
      r_gmovi.monto           := p_val_compra;
      r_gmovi.nro_documento   := r_bien.cod_bien;
      r_gmovi.cod_tasa        := null;
      r_gmovi.val_tasa        := null;
      if p_cod_moneda <> v_cod_mon_local then
         r_gmovi.mto_equ_local   := round((p_val_compra * v_cotizacion),v_redondeo);
         r_gmovi.cotizacion      := v_cotizacion;
      else
         r_gmovi.mto_equ_local   := null;
         r_gmovi.cotizacion      := null;
      end if;
      r_gmovi.cod_ofi_origen  := p_cod_oficina;
      r_gmovi.emi_aviso       := 'N';
      r_gmovi.concepto        := substr(p_descripcion,1,30)||' ///';
      r_gmovi.estado          := 'N';
      r_gmovi.reversado       := 'N';
      r_gmovi.nro_caja        := null;
      r_gmovi.cod_rubro       := NULL;
      r_gmovi.tip_mov_rubro   := null;--DEBITO
      PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, 'N'); --no es nocturno
  end if;
  p_nro_secuencia := v_nro_secuencia;
exception
   when others then
      raise_application_error(-20000,'Factura '||p_nro_factura||' '||sqlerrm);
end;
/

