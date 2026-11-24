CREATE OR REPLACE PROCEDURE IT.PRZ_BAJ_SUMINISTRO (
   p_ofi_origen   in_suministros.cod_oficina%type,
   p_area_origen  in_suministros.cod_area%type,
   p_cod_articulo in_suministros.cod_articulo%type,
   p_cod_bien     in_suministros.cod_suministro%type,
   p_cantidad     number,
   p_fec_baja     in_suministros.fecha%type,
   p_tip_baja     in_suministros.estado%type,
   p_tip_proceso  varchar2 )
is
  -- Datos para generar el movimiento
  v_fec_actual        date         := pag_cal.fu_obt_fec_actual(13); -- fecha de hoy
  v_hor_actual        varchar2(08) := to_char(sysdate,'HH24:MI:SS'); -- Hora actual
  v_cod_usuario       varchar2(10) := upper(user);                   -- usuario
  v_nro_secuencia     number(3)    := 0;                             -- secuencia del mov.
  r_tip_baja          af_tip_movimientos%rowtype;
  r_gmovi             ge_movimientos%rowtype;
  r_articulo          af_articulos%rowtype;
  r_suministro        in_suministros%rowtype;
  v_tot_compra        pv_compras_det.val_total%type;
  --
  cursor c_suministro  is
  select cod_suministro
  from   in_suministros
  where  cod_articulo  = p_cod_articulo
  and    estado        in('A','T')
  and    p_tip_proceso =  'C'
  and    cod_oficina   = p_ofi_origen
  and    cod_area      = p_area_origen
  and    rownum       <= p_cantidad
  order by fecha desc;
  ---
  cursor c_rev_suministro  is
  select cod_suministro
  from   in_suministros
  where  cod_articulo  = p_cod_articulo
  and    estado        in('M')
  and    p_tip_proceso =  'C'
  and    cod_oficina   = p_ofi_origen
  and    cod_area      = p_area_origen
  and    rownum       <= p_cantidad
  order by fecha desc;
  
begin
  if nvl(p_cod_bien,0) = 0 and nvl(p_cantidad,0) = 0 then
     raise_application_error(-20000,'Debe ingresar un suministro o la cantidad');
  end if;
  ---
  if nvl(p_cod_bien,0) <> 0 and nvl(p_cantidad,0) <> 0 then
     raise_application_error(-20000,'Debe ingresar solo el suministro o solo la cantidad');
  end if;
  ---
  if nvl(p_tip_baja,'A') = 'A' then
     raise_application_error(-20000,'Debe ingresar un nuevo estado para el bien');
  end if;
  ---
  if p_fec_baja is null then
     raise_application_error(-20000,'Debe ingresar la fecha de baja');
  end if;
  ---
  if p_tip_proceso not in ('C','E') then
     raise_application_error(-20000,'Tipo de proceso no corresponde');
  end if;
  ---
 	begin
     PRF_OBT_ARTICULO (p_cod_articulo, r_articulo);
     if p_area_origen = fug_obt_pardinamico ('AREA_EMBOZADO') and r_articulo.cod_tip_articulo <> fug_obt_pardinamico ('TIP_ARTICULO')  then
        raise_application_error(-20000,'Para el Área Embozado, el Artículo seleccionado debe ser de Tipo Plástico de Tarj. ');
     end if;	
	end;
  
  ---
  --- Actualizo el bien
  ---
  if nvl(p_cod_bien,0) <> 0 then
     if fug_obt_tip_implementacion = 1 and nvl(p_tip_baja,'X') = 'R'  and p_area_origen = fug_obt_pardinamico('AREA_EMBOZADO') then
         update in_suministros
         set    fecha          = p_fec_baja,
                estado         = 'T'
         where  cod_suministro = p_cod_bien;
         ---
         if r_suministro.estado = 'A' or r_articulo.cod_tip_articulo = fug_obt_pardinamico ('TIP_ARTICULO') then
           PRF_ACT_ARTICULOS(r_articulo.cod_articulo);

 		--- Actualiza la Cantidad de Artículos en Inventario   -- AP 1030     
            	UPDATE af_articulos
               	SET can_total = nvl(can_total, 0) + 1
             	WHERE cod_articulo = p_cod_articulo;
            	IF SQL%NOTFOUND THEN
               	raise_application_error(-20000, 'El articulo no fue actualizado');
            	END IF;
         end if;
         PRZ_OBT_SUMINISTRO(p_cod_bien, r_suministro);
         PRF_OBT_ARTICULO(r_suministro.cod_articulo,r_articulo);   
           
         v_tot_compra := nvl(r_suministro.val_compra,0) * -1;
     else  
         update in_suministros
         set    fecha          = p_fec_baja,
                estado         = p_tip_baja
         where  cod_suministro = p_cod_bien;
         ---
         if r_suministro.estado = 'A' or r_articulo.cod_tip_articulo = fug_obt_pardinamico ('TIP_ARTICULO') then
           PRF_ACT_ARTICULOS(r_articulo.cod_articulo);
         end if;
         PRZ_OBT_SUMINISTRO(p_cod_bien, r_suministro);
         PRF_OBT_ARTICULO(r_suministro.cod_articulo,r_articulo);
               
         v_tot_compra := nvl(r_suministro.val_compra,0);
     end if;            
  ---
  elsif nvl(p_tip_baja,'X') <> 'R'  then
  ---
      for i in c_suministro loop
        PRZ_OBT_SUMINISTRO(i.cod_suministro, r_suministro);
        v_tot_compra := nvl(v_tot_compra,0) + nvl(r_suministro.val_compra,0);
        PRF_OBT_ARTICULO(r_suministro.cod_articulo, r_articulo);

        if r_suministro.estado = 'A' or r_articulo.cod_tip_articulo = fug_obt_pardinamico ('TIP_ARTICULO') then
           PRF_ACT_ARTICULOS(r_articulo.cod_articulo);
        end if;
        --- Actualizo el suministro
        update in_suministros
        set    fecha          = p_fec_baja,
               estado         = p_tip_baja
        where  cod_suministro = r_suministro.cod_suministro;
        if sql%notfound then
           raise_application_error(-20000,
           'El suministro no fue actualizado');
        end if;   
      end loop;
  ---    
  elsif fug_obt_tip_implementacion = 1 and nvl(p_tip_baja,'X') = 'R' and p_area_origen = fug_obt_pardinamico ('AREA_EMBOZADO') and r_articulo.cod_tip_articulo = fug_obt_pardinamico ('TIP_ARTICULO') then     
  ---
      for i in c_rev_suministro loop
        PRZ_OBT_SUMINISTRO(i.cod_suministro, r_suministro);
        v_tot_compra := nvl(v_tot_compra,0) + nvl(r_suministro.val_compra,0);          
        PRF_OBT_ARTICULO(r_suministro.cod_articulo, r_articulo);   
      
     ---Actualizo el suministro si Plástico de Tarjetas 
        update in_suministros
        set    fecha          = p_fec_baja,
               estado         = 'T'
        where  cod_suministro = r_suministro.cod_suministro;
        if sql%notfound then
           raise_application_error(-20000,
           'El suministro no fue actualizado');
        end if;  
     
      end loop;
        v_tot_compra := (nvl(v_tot_compra,0)*-1);
      --- Actualiza la Cantidad de Artículos en Inventario       
        Update af_articulos
          set can_total = nvl(can_total,0) + p_cantidad
          where  cod_articulo = r_articulo.cod_articulo;
         if sql%notfound then
           raise_application_error(-20000,'El articulo no fue actualizado');
         end if;
  end if;      
      ---
  if nvl(r_suministro.cod_suministro,0) = 0 then
    raise_application_error(-20000,'No existen suministros a dar de baja');
  end if;

  ---
  ---------------------------
  --- INSERTAR MOVIMIENTO ---
  ---------------------------
  ---
  --- Depreciacion Acumulada
  ---
 /* v_hor_actual            := pag_gen.fu_obt_sig_segundo(v_hor_actual);
  -- Aumento la secuencia
  v_nro_secuencia         := nvl(v_nro_secuencia,0) + 1;
  ---
  v_tot_compra := nvl(r_suministro.val_compra,0);
  ---
  -- Genero el movimiento
  r_gmovi.cod_modulo      := r_articulo.cod_modulo;
  r_gmovi.cod_modalidad   := r_articulo.cod_modalidad;
  r_gmovi.cod_oficina     := r_suministro.cod_oficina;
  r_gmovi.nro_cuenta      := null;
  r_gmovi.cod_moneda      := r_suministro.cod_moneda;
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
  r_gmovi.monto           := v_tot_compra;
  r_gmovi.nro_documento   := r_suministro.cod_suministro;
  r_gmovi.cod_tasa        := null;
  r_gmovi.val_tasa        := null;
  r_gmovi.cotizacion      := null;
  r_gmovi.cod_ofi_origen  := r_suministro.cod_oficina;
  r_gmovi.emi_aviso       := 'N';
  r_gmovi.concepto        := substr(r_suministro.descripcion,1,35);
  r_gmovi.estado          := 'N';
  r_gmovi.reversado       := 'N';
  r_gmovi.nro_caja        := null;
  r_gmovi.cod_rubro       := NULL;
  r_gmovi.tip_mov_rubro   := null;--DEBITO
  PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, 'N'); -- no es nocturno*/
  ---
  --- Valor costo revaluo
  ---
  
   if fug_obt_tip_implementacion = 1 and p_tip_baja in ('M','R') then 
      if p_area_origen = fug_obt_pardinamico ('AREA_EMBOZADO') and fug_obt_pardinamico ('TIP_ARTICULO') = r_articulo.cod_tip_articulo then  
          v_hor_actual            := pag_gen.fu_obt_sig_segundo(v_hor_actual);
          -- Aumento la secuencia
          v_nro_secuencia         := nvl(v_nro_secuencia,0) + 1;
          ---
          -- Genero el movimiento
          r_gmovi.cod_modulo      := r_articulo.cod_modulo;
          r_gmovi.cod_modalidad   := r_articulo.cod_modalidad;
          r_gmovi.cod_oficina     := r_suministro.cod_oficina;
          r_gmovi.nro_cuenta      := null;
          r_gmovi.cod_moneda      := r_suministro.cod_moneda;
          r_gmovi.cod_usuario     := v_cod_usuario;
          r_gmovi.hora            := v_hor_actual;
          r_gmovi.fecha           := v_fec_actual;
          r_gmovi.nro_secuencia   := v_nro_secuencia;
          --
          r_gmovi.fec_valor       := v_fec_actual;
          r_gmovi.cod_tra_padre   := 1300;
          r_gmovi.cod_mod_padre   := r_articulo.cod_modulo;
          r_gmovi.cod_mad_padre   := r_articulo.cod_modalidad;
          r_gmovi.cod_transaccion := r_articulo.cod_tra_dep_baja; ---Transacción 3170 de Baja de Area de Embozado 
          r_gmovi.monto        := nvl(v_tot_compra,0);
          r_gmovi.nro_documento   := r_suministro.cod_suministro;
          r_gmovi.cod_tasa        := null;
          r_gmovi.val_tasa        := null;
          r_gmovi.cotizacion      := null;
          r_gmovi.cod_ofi_origen  := r_suministro.cod_oficina;
          r_gmovi.emi_aviso       := 'N';
          r_gmovi.concepto        := substr(r_suministro.descripcion,1,35);
          r_gmovi.estado          := 'N';
          r_gmovi.reversado       := 'N';
          r_gmovi.nro_caja        := null;
          r_gmovi.cod_rubro       := NULL;
          r_gmovi.tip_mov_rubro   := null;--CREDITO
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
          r_gmovi.cod_oficina     := r_suministro.cod_oficina;
          r_gmovi.nro_cuenta      := null;
          r_gmovi.cod_moneda      := r_suministro.cod_moneda;
          r_gmovi.cod_usuario     := v_cod_usuario;
          r_gmovi.hora            := v_hor_actual;
          r_gmovi.fecha           := v_fec_actual;
          r_gmovi.nro_secuencia   := v_nro_secuencia;
          --
          r_gmovi.fec_valor       := v_fec_actual;
          r_gmovi.cod_tra_padre   := 1300;
          r_gmovi.cod_mod_padre   := r_tip_baja.cod_modulo;
          r_gmovi.cod_mad_padre   := r_tip_baja.cod_modalidad;
          r_gmovi.cod_transaccion := r_tip_baja.cod_transaccion; ---Transaccion 3171 definida en af_tip_movimientos para el Tipo M 
          r_gmovi.monto        := nvl(v_tot_compra,0);
          r_gmovi.nro_documento   := r_suministro.cod_suministro;
          r_gmovi.cod_tasa        := null;
          r_gmovi.val_tasa        := null;
          r_gmovi.cotizacion      := null;
          r_gmovi.cod_ofi_origen  := r_suministro.cod_oficina;
          r_gmovi.emi_aviso       := 'N';
          r_gmovi.concepto        := substr(r_suministro.descripcion,1,35);
          r_gmovi.estado          := 'N';
          r_gmovi.reversado       := 'N';
          r_gmovi.nro_caja        := null;
          r_gmovi.cod_rubro       := NULL;
          r_gmovi.tip_mov_rubro   := null;--DEBITO
          PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, 'N'); -- no es nocturno
      else 
           raise_application_error (-20000,'El Tipo de Baja seleccionado debe ser para el Art. Plástico de Tarjetas y debe estar en Área Embozado. ');
      end if;
   else 
      v_hor_actual            := pag_gen.fu_obt_sig_segundo(v_hor_actual);
      -- Aumento la secuencia
      v_nro_secuencia         := nvl(v_nro_secuencia,0) + 1;
      ---
      -- Genero el movimiento
      r_gmovi.cod_modulo      := r_articulo.cod_modulo;
      r_gmovi.cod_modalidad   := r_articulo.cod_modalidad;
      r_gmovi.cod_oficina     := r_suministro.cod_oficina;
      r_gmovi.nro_cuenta      := null;
      r_gmovi.cod_moneda      := r_suministro.cod_moneda;
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
      r_gmovi.monto           := v_tot_compra;
      r_gmovi.nro_documento   := r_suministro.cod_suministro;
      r_gmovi.cod_tasa        := null;
      r_gmovi.val_tasa        := null;
      r_gmovi.cotizacion      := null;
      r_gmovi.cod_ofi_origen  := r_suministro.cod_oficina;
      r_gmovi.emi_aviso       := 'N';
      r_gmovi.concepto        := substr(r_suministro.descripcion,1,35);
      r_gmovi.estado          := 'N';
      r_gmovi.reversado       := 'N';
      r_gmovi.nro_caja        := null;
      r_gmovi.cod_rubro       := NULL;
      r_gmovi.tip_mov_rubro   := null;--CREDITO
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
      r_gmovi.cod_oficina     := r_suministro.cod_oficina;
      r_gmovi.nro_cuenta      := null;
      r_gmovi.cod_moneda      := r_suministro.cod_moneda;
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
      r_gmovi.monto           := nvl(v_tot_compra,0);
      r_gmovi.nro_documento   := r_suministro.cod_suministro;
      r_gmovi.cod_tasa        := null;
      r_gmovi.val_tasa        := null;
      r_gmovi.cotizacion      := null;
      r_gmovi.cod_ofi_origen  := r_suministro.cod_oficina;
      r_gmovi.emi_aviso       := 'N';
      r_gmovi.concepto        := substr(r_suministro.descripcion,1,35);
      r_gmovi.estado          := 'N';
      r_gmovi.reversado       := 'N';
      r_gmovi.nro_caja        := null;
      r_gmovi.cod_rubro       := NULL;
      r_gmovi.tip_mov_rubro   := null;--DEBITO
      PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, 'N'); -- no es nocturno
   end if;
end;
/

