CREATE OR REPLACE PROCEDURE IT.PRZ_TRA_SUMINISTRO (
   p_ofi_origen   in_suministros.cod_oficina%type,
   p_area_origen  in_suministros.cod_area%type,
   p_cod_articulo in_suministros.cod_articulo%type,
   p_cod_bien     in_suministros.cod_suministro%type,
   p_cantidad     number,
   p_fec_baja     date,
   p_ofi_destino  in_suministros.cod_oficina%type,
   p_area_destino in_suministros.cod_area%type,
   p_tip_proceso  varchar2)
is
  -- Datos para generar el movimiento
  v_fec_actual        date         := pag_cal.fu_obt_fec_actual(13); -- fecha de hoy
  v_hor_actual        varchar2(08) := to_char(sysdate,'HH24:MI:SS'); -- Hora actual
  v_cod_usuario       varchar2(10) := upper(user);                   -- usuario
  v_nro_secuencia     number(3)    := 0;                             -- secuencia del mov.
  r_bien              af_bienes%rowtype;
  r_articulo          af_articulos%rowtype;
  r_gmovi             ge_movimientos%rowtype;
  r_suministro        in_suministros%rowtype;
  v_tot_compra        pv_compras_det.val_total%type;
  v_cod_mon_local     ba_monedas.cod_moneda%type := pag_gen.FU_OBT_MON_LOCAL;
  v_val_compra        in_suministros.val_compra%type;
  v_tra_alta_deposito ge_transacciones.cod_transaccion%type;
  v_tra_baja_deposito ge_transacciones.cod_transaccion%type;
  v_tra_alta_procesadora ge_transacciones.cod_transaccion%type;
  v_tra_baja_procesadora ge_transacciones.cod_transaccion%type;
  v_tra_alta_embozado ge_transacciones.cod_transaccion%type;
  v_tra_baja_embozado ge_transacciones.cod_transaccion%type;
  v_tra_baja_fabricacion ge_transacciones.cod_transaccion%type;

  --
  cursor c_suministro is
  select cod_suministro, cod_articulo
  from   in_suministros
  where  cod_articulo = p_cod_articulo
  and    estado       = p_tip_proceso
  and    cod_oficina  = p_ofi_origen
  and    cod_area     = p_area_origen
  and    rownum      <= p_cantidad
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
  if p_fec_baja is null then
     raise_application_error(-20000,'Debe ingresar la fecha de baja');
  end if;
  ---
  if nvl(p_ofi_destino,0) = 0 then
     raise_application_error(-20000,'Debe ingresar la oficina de destino');
  end if;
  ---
  if nvl(p_area_destino,0) = 0 then
     raise_application_error(-20000,'Debe ingresar el area de destino');
  end if;
  ---
  if p_tip_proceso not in ('A','T') then
     raise_application_error(-20000,'Tipo de proceso no corresponde');
  end if;
  ---
  if nvl(p_cod_bien,0) <> 0 then
     BEGIN
       SELECT *
       INTO   r_bien
       FROM   AF_BIENES
       WHERE  COD_BIEN = P_COD_BIEN;
     EXCEPTION
       WHEN NO_DATA_FOUND THEN
            r_bien.cod_bien := null;
            r_bien.cod_articulo := null;
       WHEN OTHERS THEN
            raise_application_error(-20000,
            'Rec.Bien '||to_char(P_COD_BIEN)||' '||sqlerrm);
     END;

     if NVL(r_bien.cod_bien,0) <> 0 then
        PRF_OBT_ARTICULO(r_bien.cod_articulo, r_articulo);
        if nvl(r_articulo.ind_act_fijo,'N') = 'S' then
           raise_application_error(-20000,'Este Suministro es un Activo Fijo.'
                                   || ' Debe procesar por Tranferencia de Bienes.');
        end if;
     end if;
     ---

     PRZ_OBT_SUMINISTRO(p_cod_bien, r_suministro);

     PRF_OBT_ARTICULO(r_suministro.cod_articulo, r_articulo);
     
     if r_suministro.estado = 'A' and r_articulo.cod_tip_articulo <> fug_obt_pardinamico ('TIP_ARTICULO')  then
        PRF_ACT_ARTICULOS(r_articulo.cod_articulo);
     end if;
     ---
     if r_suministro.cod_oficina = p_ofi_destino and
        fug_obt_tip_implementacion = 2 then
        null;
     ---
       -------------------------------------
       --- MOVIMIENTOS OFICINA DE ORIGEN ---
       -------------------------------------
      
     elsif fug_obt_pardinamico ('TIP_ARTICULO') = r_articulo.cod_tip_articulo then 
         if (fug_obt_pardinamico('AREA_FABRICACION') = r_suministro.cod_area and p_area_destino = fug_obt_pardinamico ('AREA_DEPOSITO')) 
            or (r_suministro.cod_area = fug_obt_pardinamico  ('AREA_DEPOSITO') and p_area_destino = fug_obt_pardinamico('AREA_FABRICACION') and p_tip_proceso = 'T'  )  then
            begin  
             select g.cod_transaccion 
              into v_tra_alta_deposito
             from ge_gru_transacciones_det g, ge_transacciones t 
             where g.cod_gru_transaccion = fug_obt_pardinamico ('GRU_TRA_DEPOSITO')
             and g.cod_transaccion = t.cod_transaccion
             and g.cod_modulo = t.cod_modulo
             and g.cod_modalidad = t.cod_modalidad
             and t.tipo = 'C';
            exception 
              when others then 
               raise_application_error(-20000,'Error al Obtener el Grupo de Transacción de Alta de Depósito. ');
            end; 
            begin  
             select g.cod_transaccion 
              into v_tra_baja_fabricacion
             from ge_gru_transacciones_det g, ge_transacciones t 
             where g.cod_gru_transaccion = fug_obt_pardinamico ('GRU_TRA_FABRICACION')
             and g.cod_transaccion = t.cod_transaccion
             and g.cod_modulo = t.cod_modulo
             and g.cod_modalidad = t.cod_modalidad
             and t.tipo = 'D';
            exception 
              when others then 
               raise_application_error(-20000,'Error al Obtener el Grupo de Transacción de Baja de Fabricación. ');
            end;
            if fug_obt_pardinamico('AREA_FABRICACION') = r_suministro.cod_area and p_area_destino = fug_obt_pardinamico ('AREA_DEPOSITO') then     
              Update af_articulos
                  set can_total = nvl(can_total,0) + 1,
                      fec_ult_movimiento = v_fec_actual,
                      hor_ult_movimiento = v_hor_actual
                where  cod_articulo = r_articulo.cod_articulo;
              if sql%notfound then
                   raise_application_error(-20000,'El articulo no fue actualizado');
              end if;  		
            else 
              Update af_articulos
                  set can_total = nvl(can_total,0) -1 ,
                      fec_ult_movimiento = v_fec_actual,
                      hor_ult_movimiento = v_hor_actual
                where  cod_articulo = r_articulo.cod_articulo;
              if sql%notfound then
                   raise_application_error(-20000,'El articulo no fue actualizado');
              end if;  
              update in_suministros 
                set estado = 'A' 
                where cod_suministro = r_suministro.cod_suministro
                and estado = 'T';
            end if;
             v_hor_actual            := pag_gen.fu_obt_sig_segundo(v_hor_actual);
             -- Aumento la secuencia
             v_nro_secuencia         := nvl(v_nro_secuencia,0) + 1;
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
             r_gmovi.cod_transaccion := v_tra_alta_deposito;
             if fug_obt_pardinamico('AREA_FABRICACION') = r_suministro.cod_area and p_area_destino = fug_obt_pardinamico ('AREA_DEPOSITO') then 
                 r_gmovi.monto       := nvl(r_suministro.val_compra,0);
             else
                 r_gmovi.monto       := (nvl(r_suministro.val_compra,0) *-1);
             end if;    
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
             ---
             --------------------------------------
             --- MOVIMIENTOS OFICINA DE DESTINO ---
             --------------------------------------
             ---
             ---
             v_hor_actual            := pag_gen.fu_obt_sig_segundo(v_hor_actual);
             -- Aumento la secuencia
             v_nro_secuencia         := nvl(v_nro_secuencia,0) + 1;
             -- Genero el movimiento
             r_gmovi.cod_modulo      := r_articulo.cod_modulo;
             r_gmovi.cod_modalidad   := r_articulo.cod_modalidad;
             r_gmovi.cod_oficina     := p_ofi_destino;
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
             r_gmovi.cod_transaccion := v_tra_baja_fabricacion;
             if fug_obt_pardinamico('AREA_FABRICACION') = r_suministro.cod_area and p_area_destino = fug_obt_pardinamico ('AREA_DEPOSITO') then
               r_gmovi.monto         := nvl(r_suministro.val_compra,0);
             else 
               r_gmovi.monto         := (nvl(r_suministro.val_compra,0) *-1);
             end if;
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
       
        --- Fin de Movimiento para Plásticos de Tarjetas (De Fabricación a Depósito)
         
        --- Movimiento para Plásticos de Tarjetas (De Depósito a Procesadora)
         elsif (fug_obt_pardinamico('AREA_DEPOSITO') = r_suministro.cod_area and p_area_destino = fug_obt_pardinamico ('AREA_PROCESADORA') and p_tip_proceso = 'T' ) or
             ( fug_obt_pardinamico ('AREA_PROCESADORA')  = r_suministro.cod_area and p_area_destino = fug_obt_pardinamico('AREA_DEPOSITO') and p_tip_proceso = 'T' ) then          
           begin 
             select g.cod_transaccion 
              into v_tra_alta_procesadora
             from ge_gru_transacciones_det g, ge_transacciones t 
             where g.cod_gru_transaccion = fug_obt_pardinamico ('GRU_TRA_PROCESADORA')
             and g.cod_transaccion = t.cod_transaccion
             and g.cod_modulo = t.cod_modulo
             and g.cod_modalidad = t.cod_modalidad
             and t.tipo = 'C';

           exception 
              when others then 
               raise_application_error(-20000,'Error al Obtener el Grupo de Transacción de Procesadora. ');
           end; 
           begin 
             select g.cod_transaccion 
              into v_tra_baja_deposito 
             from ge_gru_transacciones_det g, ge_transacciones t 
             where g.cod_gru_transaccion = fug_obt_pardinamico ('GRU_TRA_DEPOSITO')
             and g.cod_transaccion = t.cod_transaccion
             and g.cod_modulo = t.cod_modulo
             and g.cod_modalidad = t.cod_modalidad
             and t.tipo = 'D';
           exception 
              when others then 
               raise_application_error(-20000,'Error al Obtener el Grupo de Transacción de Depósito. ');
           end;   
             v_hor_actual            := pag_gen.fu_obt_sig_segundo(v_hor_actual);
             -- Aumento la secuencia
             v_nro_secuencia         := nvl(v_nro_secuencia,0) + 1;
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
             r_gmovi.cod_transaccion := v_tra_alta_procesadora;
             if fug_obt_pardinamico('AREA_DEPOSITO') = r_suministro.cod_area and p_area_destino = fug_obt_pardinamico ('AREA_PROCESADORA') then
               r_gmovi.monto           := nvl(r_suministro.val_compra,0);       
             else 
               r_gmovi.monto           := (nvl(r_suministro.val_compra,0)*-1);
             end if;  
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
             ---
             --------------------------------------
             --- MOVIMIENTOS OFICINA DE DESTINO ---
             --------------------------------------
             ---
             ---
             v_hor_actual            := pag_gen.fu_obt_sig_segundo(v_hor_actual);
             -- Aumento la secuencia
             v_nro_secuencia         := nvl(v_nro_secuencia,0) + 1;
             -- Genero el movimiento
             r_gmovi.cod_modulo      := r_articulo.cod_modulo;
             r_gmovi.cod_modalidad   := r_articulo.cod_modalidad;
             r_gmovi.cod_oficina     := p_ofi_destino;
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
             r_gmovi.cod_transaccion := v_tra_baja_deposito;
             if fug_obt_pardinamico('AREA_DEPOSITO') = r_suministro.cod_area and p_area_destino = fug_obt_pardinamico ('AREA_PROCESADORA') then
               r_gmovi.monto           := nvl(r_suministro.val_compra,0);       
             else 
               r_gmovi.monto           := (nvl(r_suministro.val_compra,0)*-1);
             end if; 
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
        --- Fin de Movimiento para Plásticos de Tarjetas (De Depósito a Procesadora)        
         
        --- Movimiento para Plásticos de Tarjetas (De Procesadora a Embozado)
         elsif (fug_obt_pardinamico('AREA_PROCESADORA') = r_suministro.cod_area and p_area_destino = fug_obt_pardinamico ('AREA_EMBOZADO') and p_tip_proceso = 'T' )or
             (fug_obt_pardinamico ('AREA_EMBOZADO') = r_suministro.cod_area and p_area_destino = fug_obt_pardinamico('AREA_PROCESADORA')and p_tip_proceso = 'T'  ) then
           begin   
             select g.cod_transaccion 
              into v_tra_alta_embozado
             from ge_gru_transacciones_det g, ge_transacciones t 
             where g.cod_gru_transaccion = fug_obt_pardinamico ('GRU_TRA_EMBOZADO')
             and g.cod_transaccion = t.cod_transaccion
             and g.cod_modulo = t.cod_modulo
             and g.cod_modalidad = t.cod_modalidad
             and t.tipo = 'C';
           exception 
              when others then 
               raise_application_error(-20000,'Error al Obtener el Grupo de Transacción de Alta de Embozado. ');
           end;   
           begin 
             select g.cod_transaccion 
              into v_tra_baja_procesadora  
             from ge_gru_transacciones_det g, ge_transacciones t 
             where g.cod_gru_transaccion = fug_obt_pardinamico ('GRU_TRA_PROCESADORA')
             and g.cod_transaccion = t.cod_transaccion
             and g.cod_modulo = t.cod_modulo
             and g.cod_modalidad = t.cod_modalidad
             and t.tipo = 'D';
           exception 
              when others then 
               raise_application_error(-20000,'Error al Obtener el Grupo de Transacción de Baja de Procesadora. ');
           end;   
             v_hor_actual            := pag_gen.fu_obt_sig_segundo(v_hor_actual);
             -- Aumento la secuencia
             v_nro_secuencia         := nvl(v_nro_secuencia,0) + 1;
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
             r_gmovi.cod_transaccion := v_tra_alta_embozado;
             if fug_obt_pardinamico('AREA_PROCESADORA') = r_suministro.cod_area and p_area_destino = fug_obt_pardinamico ('AREA_EMBOZADO') then
                r_gmovi.monto           := nvl(r_suministro.val_compra,0);
             else
                r_gmovi.monto           := (nvl(r_suministro.val_compra,0)*-1);
             end if;
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
             ---
             --------------------------------------
             --- MOVIMIENTOS OFICINA DE DESTINO ---
             --------------------------------------
             ---
             ---
             v_hor_actual            := pag_gen.fu_obt_sig_segundo(v_hor_actual);
             -- Aumento la secuencia
             v_nro_secuencia         := nvl(v_nro_secuencia,0) + 1;
             -- Genero el movimiento
             r_gmovi.cod_modulo      := r_articulo.cod_modulo;
             r_gmovi.cod_modalidad   := r_articulo.cod_modalidad;
             r_gmovi.cod_oficina     := p_ofi_destino;
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
             r_gmovi.cod_transaccion := v_tra_baja_procesadora;
             if fug_obt_pardinamico('AREA_PROCESADORA') = r_suministro.cod_area and p_area_destino = fug_obt_pardinamico ('AREA_EMBOZADO') then
                r_gmovi.monto        := nvl(r_suministro.val_compra,0);
             else
                r_gmovi.monto        := (nvl(r_suministro.val_compra,0)*-1);
             end if;
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
        --- Fin de Movimiento para Plásticos de Tarjetas (De Procesadora a Embozado)   
           
         else --- Si no se cumple ninguna de las Condiciones del Circuito de Plásticos debe dar Error
           raise_application_error (-20000, 'No puede realizarse la Transferencia solicitada desde Área Origen:'||' '||p_area_origen||' '|| 'y Área Destino:'||' '||p_area_destino||' '||'Verifique.');     
         end if;
        ---    
     elsif p_area_destino in (fug_obt_pardinamico('AREA_PROCESADORA'),fug_obt_pardinamico('AREA_FABRICACION'),fug_obt_pardinamico('AREA_DEPOSITO'),fug_obt_pardinamico('AREA_EMBOZADO')) and r_articulo.cod_tip_articulo <> 14 then 
           raise_application_error (-20000, 'No puede realizarse la Transferencia solicitada desde Área Origen:'||' '||p_area_origen||' '|| 'y Área Destino:'||' '||p_area_destino||' '||'Verifique.');                  
     else
        if p_cod_articulo is null then
           raise_application_error(-20000,'Debe ingresar el articulo');
        end if;
         -------------------------------------
         --- MOVIMIENTOS OFICINA DE ORIGEN ---
         -------------------------------------
         ---
         ---
         v_hor_actual            := pag_gen.fu_obt_sig_segundo(v_hor_actual);
         -- Aumento la secuencia
         v_nro_secuencia         := nvl(v_nro_secuencia,0) + 1;
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
         r_gmovi.cod_transaccion := r_articulo.cod_tra_alta;
         r_gmovi.monto           := nvl(r_suministro.val_compra,0);
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
         ---
         --------------------------------------
         --- MOVIMIENTOS OFICINA DE DESTINO ---
         --------------------------------------
         ---
         ---
         v_hor_actual            := pag_gen.fu_obt_sig_segundo(v_hor_actual);
         -- Aumento la secuencia
         v_nro_secuencia         := nvl(v_nro_secuencia,0) + 1;
         -- Genero el movimiento
         r_gmovi.cod_modulo      := r_articulo.cod_modulo;
         r_gmovi.cod_modalidad   := r_articulo.cod_modalidad;
         r_gmovi.cod_oficina     := p_ofi_destino;
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
         r_gmovi.monto           := nvl(r_suministro.val_compra ,0);
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
       --- Actualizo el suministro

	-- AP 1030 -- Actualiza en estado A cuando reversa de Deposito a Fábrica

 	if fug_obt_pardinamico('AREA_DEPOSITO') = r_suministro.cod_area and p_area_destino = fug_obt_pardinamico ('AREA_FABRICACION') then 

       		update in_suministros
       		set    cod_oficina     = p_ofi_destino,
              		cod_area        = p_area_destino,
              		estado          = 'A',
          		fec_transferencia = v_fec_actual
       		where  cod_suministro  = p_cod_bien;
       		if sql%notfound then
          		raise_application_error(-20000,
          		'El suministro no fue actualizado');
       		end if;
	else
       		update in_suministros
       		set    cod_oficina     = p_ofi_destino,
              		cod_area        = p_area_destino,
              		estado          = 'T',
          		fec_transferencia = v_fec_actual
       		where  cod_suministro  = p_cod_bien;
       		if sql%notfound then
          		raise_application_error(-20000,
          		'El suministro no fue actualizado');
       		end if;
	end if;
   ---
   else
   ---
     for i in c_suministro loop
        PRF_OBT_ARTICULO(p_cod_articulo, r_articulo);
        if nvl(r_articulo.ind_act_fijo,'N') = 'S' then
          raise_application_error(-20000,'Este Suministro es un Activo Fijo.'
                          || ' Debe procesar por Tranferencia de Bienes.');
        end if;
        PRZ_OBT_SUMINISTRO(i.cod_suministro, r_suministro);
        if r_suministro.cod_moneda <> v_cod_mon_local then
           v_val_compra := nvl(pag_gen.FU_CON_MON_A_MONEDA(r_suministro.cod_moneda, v_cod_mon_local, nvl(r_suministro.val_compra,0), pag_gen.FU_OBT_COTIZACION(r_suministro.cod_moneda,r_suministro.fecha)),0);
        else
           v_val_compra := nvl(r_suministro.val_compra,0);
        end if;
        v_tot_compra := nvl(v_tot_compra,0) + v_val_compra;
        PRF_OBT_ARTICULO(r_suministro.cod_articulo, r_articulo);
        
        ---Si es de Tipo Plásticos de Tarjetas y el Estado es T(ransferido) se debe restar del Inventario del Artículo
        if r_suministro.estado = 'A' and r_articulo.cod_tip_articulo <> fug_obt_pardinamico ('TIP_ARTICULO')  then
           PRF_ACT_ARTICULOS(r_articulo.cod_articulo);
        end if;
        --- Actualizo el Suministro a estado 'A' si la reversión se realiza del Área de Depósito a Fabricación
        if  fug_obt_pardinamico ('AREA_DEPOSITO') = r_suministro.cod_area and p_area_destino = fug_obt_pardinamico('AREA_FABRICACION') then   
            update in_suministros 
            set    cod_oficina     = p_ofi_destino,
                   cod_area        = p_area_destino,
                   estado = 'A', 
                   fec_transferencia = v_fec_actual
                where cod_suministro = i.cod_suministro
                and estado = 'T';
            if sql%notfound then
               raise_application_error(-20000,
               'El suministro no fue actualizado');
            end if;    
        else   
        --- Actualizo el suministro
            update in_suministros
            set    cod_oficina     = p_ofi_destino,
                   cod_area        = p_area_destino,
                   estado          = 'T',
               fec_transferencia = v_fec_actual
            where  cod_suministro  = i.cod_suministro;
            if sql%notfound then
               raise_application_error(-20000,
               'El suministro no fue actualizado');
            end if;
        end if;    
      end loop;
      ---
       if nvl(r_suministro.cod_suministro,0) = 0 then
          raise_application_error(-20000,'No existen suministros a trasferir');
       end if;
      ---
       if fug_obt_pardinamico ('TIP_ARTICULO') = r_articulo.cod_tip_articulo  then 
         --- Movimientos para Plásticos de Tarjetas (De Fabricación a Depósito)
        if (fug_obt_pardinamico('AREA_FABRICACION') = r_suministro.cod_area and p_area_destino = fug_obt_pardinamico ('AREA_DEPOSITO') )
             or ( fug_obt_pardinamico ('AREA_DEPOSITO') = r_suministro.cod_area and p_area_destino = fug_obt_pardinamico('AREA_FABRICACION')and p_tip_proceso = 'T'  )then
             begin 
               select g.cod_transaccion 
                into v_tra_alta_deposito
               from ge_gru_transacciones_det g, ge_transacciones t 
               where g.cod_gru_transaccion = fug_obt_pardinamico ('GRU_TRA_DEPOSITO')
               and g.cod_transaccion = t.cod_transaccion
               and g.cod_modulo = t.cod_modulo
               and g.cod_modalidad = t.cod_modalidad
               and t.tipo = 'C';
              exception 
                  when others then 
                   raise_application_error(-20000,'Error al Obtener el Grupo de Transacción de Alta en Depósito. ');
              end;  
                
              begin
               select g.cod_transaccion 
                into v_tra_baja_fabricacion
               from ge_gru_transacciones_det g, ge_transacciones t 
               where g.cod_gru_transaccion = fug_obt_pardinamico ('GRU_TRA_FABRICACION')
               and g.cod_transaccion = t.cod_transaccion
               and g.cod_modulo = t.cod_modulo
               and g.cod_modalidad = t.cod_modalidad
               and t.tipo = 'D';
              exception 
                  when others then 
                   raise_application_error(-20000,'Error al Obtener el Grupo de Transacción de Baja de Fabricación. ');
              end; 
                
              if  (fug_obt_pardinamico('AREA_FABRICACION') = r_suministro.cod_area and p_area_destino = fug_obt_pardinamico ('AREA_DEPOSITO')) then
                Update af_articulos
                  set can_total = nvl(can_total,0) + p_cantidad,
                      fec_ult_movimiento = v_fec_actual,
                      hor_ult_movimiento = v_hor_actual
                where  cod_articulo = r_articulo.cod_articulo;
                  if sql%notfound then
                     raise_application_error(-20000,'El articulo no fue actualizado');
                  end if;
              else 
                Update af_articulos
                  set can_total = nvl(can_total,0) - p_cantidad,
                      fec_ult_movimiento = v_fec_actual,
                      hor_ult_movimiento = v_hor_actual
                where  cod_articulo = r_articulo.cod_articulo;
                if sql%notfound then
                   raise_application_error(-20000,'El articulo no fue actualizado');
                end if;  
              end if;  
           --------------------------------------
           --- MOVIMIENTOS OFICINA DE DESTINO ---
           --------------------------------------
           v_hor_actual            := pag_gen.fu_obt_sig_segundo(v_hor_actual);
           -- Aumento la secuencia
           v_nro_secuencia         := nvl(v_nro_secuencia,0) + 1;
           -- Genero el movimiento
           r_gmovi.cod_modulo      := r_articulo.cod_modulo;
           r_gmovi.cod_modalidad   := r_articulo.cod_modalidad;
           r_gmovi.cod_oficina     := p_ofi_destino;
           r_gmovi.nro_cuenta      := null;
           r_gmovi.cod_moneda      := v_cod_mon_local;
           r_gmovi.cod_usuario     := v_cod_usuario;
           r_gmovi.hora            := v_hor_actual;
           r_gmovi.fecha           := v_fec_actual;
           r_gmovi.nro_secuencia   := v_nro_secuencia;
           --
           r_gmovi.fec_valor       := v_fec_actual;
           r_gmovi.cod_tra_padre   := 1300;
           r_gmovi.cod_mod_padre   := r_articulo.cod_modulo;
           r_gmovi.cod_mad_padre   := r_articulo.cod_modalidad;
           r_gmovi.cod_transaccion := v_tra_baja_fabricacion;
           if fug_obt_pardinamico('AREA_FABRICACION') = r_suministro.cod_area and p_area_destino = fug_obt_pardinamico ('AREA_DEPOSITO') then
             r_gmovi.monto         := nvl(v_tot_compra,0);
           else 
             r_gmovi.monto         := (nvl(v_tot_compra,0)*-1);
           end if;
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
           ---
           -------------------------------------
           --- MOVIMIENTOS DE ALTA 
           -------------------------------------
           ---
           ---
           v_hor_actual            := pag_gen.fu_obt_sig_segundo(v_hor_actual);
           -- Aumento la secuencia
           v_nro_secuencia         := nvl(v_nro_secuencia,0) + 1;
           -- Genero el movimiento
           r_gmovi.cod_modulo      := r_articulo.cod_modulo;
           r_gmovi.cod_modalidad   := r_articulo.cod_modalidad;
           r_gmovi.cod_oficina     := r_suministro.cod_oficina;
           r_gmovi.nro_cuenta      := null;
           r_gmovi.cod_moneda      := v_cod_mon_local;
           r_gmovi.cod_usuario     := v_cod_usuario;
           r_gmovi.hora            := v_hor_actual;
           r_gmovi.fecha           := v_fec_actual;
           r_gmovi.nro_secuencia   := v_nro_secuencia;
           --
           r_gmovi.fec_valor       := v_fec_actual;
           r_gmovi.cod_tra_padre   := 1300;
           r_gmovi.cod_mod_padre   := r_articulo.cod_modulo;
           r_gmovi.cod_mad_padre   := r_articulo.cod_modalidad;
           r_gmovi.cod_transaccion := v_tra_alta_deposito;
           if fug_obt_pardinamico('AREA_FABRICACION') = r_suministro.cod_area and p_area_destino = fug_obt_pardinamico ('AREA_DEPOSITO') then
             r_gmovi.monto         := nvl(v_tot_compra,0);
           else 
             r_gmovi.monto         := (nvl(v_tot_compra,0)*-1);
           end if;
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
           r_gmovi.tip_mov_rubro   := null;
           PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, 'N'); 
          ---Fin de Movimientos para Plásticos de Tarjetas (De Fabricación a Depósito)
          
          --- Movimientos para Plásticos de Tarjetas (De Depósito a Procesadora)
        elsif (fug_obt_pardinamico('AREA_DEPOSITO') = r_suministro.cod_area and p_area_destino = fug_obt_pardinamico ('AREA_PROCESADORA')and p_tip_proceso = 'T' ) or 
             (fug_obt_pardinamico ('AREA_PROCESADORA') = r_suministro.cod_area and p_area_destino = fug_obt_pardinamico('AREA_DEPOSITO')and p_tip_proceso = 'T' )   then
                begin 
                   select g.cod_transaccion 
                    into v_tra_alta_procesadora 
                   from ge_gru_transacciones_det g, ge_transacciones t 
                   where g.cod_gru_transaccion = fug_obt_pardinamico ('GRU_TRA_PROCESADORA')
                   and g.cod_transaccion = t.cod_transaccion
                   and g.cod_modulo = t.cod_modulo
                   and g.cod_modalidad = t.cod_modalidad
                   and t.tipo = 'C';
                exception 
                   when others then 
                    raise_application_error(-20000,'Error al Obtener el Grupo de Transacción de Alta de Procesadora. ');
                end;
                begin   
                   select g.cod_transaccion 
                    into v_tra_baja_deposito 
                   from ge_gru_transacciones_det g, ge_transacciones t 
                   where g.cod_gru_transaccion = fug_obt_pardinamico ('GRU_TRA_DEPOSITO')
                   and g.cod_transaccion = t.cod_transaccion
                   and g.cod_modulo = t.cod_modulo
                   and g.cod_modalidad = t.cod_modalidad
                   and t.tipo = 'D';
                 exception 
                    when others then 
                     raise_application_error(-20000,'Error al Obtener el Grupo de Transacción de Baja de Depósito. ');
                 end; 
                
           --------------------------------------
           --- MOVIMIENTOS OFICINA DE DESTINO ---
           --------------------------------------
           v_hor_actual            := pag_gen.fu_obt_sig_segundo(v_hor_actual);
           -- Aumento la secuencia
           v_nro_secuencia         := nvl(v_nro_secuencia,0) + 1;
           -- Genero el movimiento
           r_gmovi.cod_modulo      := r_articulo.cod_modulo;
           r_gmovi.cod_modalidad   := r_articulo.cod_modalidad;
           r_gmovi.cod_oficina     := p_ofi_destino;
           r_gmovi.nro_cuenta      := null;
           r_gmovi.cod_moneda      := v_cod_mon_local;
           r_gmovi.cod_usuario     := v_cod_usuario;
           r_gmovi.hora            := v_hor_actual;
           r_gmovi.fecha           := v_fec_actual;
           r_gmovi.nro_secuencia   := v_nro_secuencia;
           --
           r_gmovi.fec_valor       := v_fec_actual;
           r_gmovi.cod_tra_padre   := 1300;
           r_gmovi.cod_mod_padre   := r_articulo.cod_modulo;
           r_gmovi.cod_mad_padre   := r_articulo.cod_modalidad;
           r_gmovi.cod_transaccion := v_tra_baja_deposito;
           if fug_obt_pardinamico('AREA_DEPOSITO') = r_suministro.cod_area and p_area_destino = fug_obt_pardinamico ('AREA_PROCESADORA') then      
             r_gmovi.monto         := nvl(v_tot_compra,0);
           else 
             r_gmovi.monto         := (nvl(v_tot_compra,0) *-1);
           end if;        
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
           ---
           -------------------------------------
           --- MOVIMIENTOS DE ALTA 
           -------------------------------------
           ---
           ---
           v_hor_actual            := pag_gen.fu_obt_sig_segundo(v_hor_actual);
           -- Aumento la secuencia
           v_nro_secuencia         := nvl(v_nro_secuencia,0) + 1;
           -- Genero el movimiento
           r_gmovi.cod_modulo      := r_articulo.cod_modulo;
           r_gmovi.cod_modalidad   := r_articulo.cod_modalidad;
           r_gmovi.cod_oficina     := r_suministro.cod_oficina;
           r_gmovi.nro_cuenta      := null;
           r_gmovi.cod_moneda      := v_cod_mon_local;
           r_gmovi.cod_usuario     := v_cod_usuario;
           r_gmovi.hora            := v_hor_actual;
           r_gmovi.fecha           := v_fec_actual;
           r_gmovi.nro_secuencia   := v_nro_secuencia;
           --
           r_gmovi.fec_valor       := v_fec_actual;
           r_gmovi.cod_tra_padre   := 1300;
           r_gmovi.cod_mod_padre   := r_articulo.cod_modulo;
           r_gmovi.cod_mad_padre   := r_articulo.cod_modalidad;
           r_gmovi.cod_transaccion := v_tra_alta_procesadora;
           if fug_obt_pardinamico('AREA_DEPOSITO') = r_suministro.cod_area and p_area_destino = fug_obt_pardinamico ('AREA_PROCESADORA') then      
             r_gmovi.monto         := nvl(v_tot_compra,0);
           else 
             r_gmovi.monto         := (nvl(v_tot_compra,0) *-1);
           end if;  
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
          ---Fin de Movimientos para Plásticos de Tarjetas (De Fabricación a Depósito)
        elsif (fug_obt_pardinamico('AREA_PROCESADORA') = r_suministro.cod_area and p_area_destino = fug_obt_pardinamico ('AREA_EMBOZADO')and p_tip_proceso = 'T' ) or
              (fug_obt_pardinamico ('AREA_EMBOZADO')  = r_suministro.cod_area and p_area_destino = fug_obt_pardinamico('AREA_PROCESADORA') and p_tip_proceso = 'T' )then
              begin
                 select g.cod_transaccion 
                  into v_tra_alta_embozado 
                 from ge_gru_transacciones_det g, ge_transacciones t 
                 where g.cod_gru_transaccion = fug_obt_pardinamico ('GRU_TRA_EMBOZADO')
                 and g.cod_transaccion = t.cod_transaccion
                 and g.cod_modulo = t.cod_modulo
                 and g.cod_modalidad = t.cod_modalidad
                 and t.tipo = 'C';
              exception 
                when others then 
                 raise_application_error(-20000,'Error al Obtener el Grupo de Transacción de Alta de Embozado. ');
              end;    
              begin 
                 select g.cod_transaccion 
                  into v_tra_baja_procesadora
                 from ge_gru_transacciones_det g, ge_transacciones t 
                 where g.cod_gru_transaccion = fug_obt_pardinamico ('GRU_TRA_PROCESADORA')
                 and g.cod_transaccion = t.cod_transaccion
                 and g.cod_modulo = t.cod_modulo
                 and g.cod_modalidad = t.cod_modalidad
                 and t.tipo = 'D';
              exception 
                when others then 
                 raise_application_error(-20000,'Error al Obtener el Grupo de Transacción de Baja de Procesadora. ');
              end;    
           
           --------------------------------------
           --- MOVIMIENTOS OFICINA DE DESTINO ---
           --------------------------------------
           v_hor_actual            := pag_gen.fu_obt_sig_segundo(v_hor_actual);
           -- Aumento la secuencia
           v_nro_secuencia         := nvl(v_nro_secuencia,0) + 1;
           -- Genero el movimiento
           r_gmovi.cod_modulo      := r_articulo.cod_modulo;
           r_gmovi.cod_modalidad   := r_articulo.cod_modalidad;
           r_gmovi.cod_oficina     := p_ofi_destino;
           r_gmovi.nro_cuenta      := null;
           r_gmovi.cod_moneda      := v_cod_mon_local;
           r_gmovi.cod_usuario     := v_cod_usuario;
           r_gmovi.hora            := v_hor_actual;
           r_gmovi.fecha           := v_fec_actual;
           r_gmovi.nro_secuencia   := v_nro_secuencia;
           --
           r_gmovi.fec_valor       := v_fec_actual;
           r_gmovi.cod_tra_padre   := 1300;
           r_gmovi.cod_mod_padre   := r_articulo.cod_modulo;
           r_gmovi.cod_mad_padre   := r_articulo.cod_modalidad;
           r_gmovi.cod_transaccion := v_tra_baja_procesadora;
           if fug_obt_pardinamico('AREA_PROCESADORA') = r_suministro.cod_area and p_area_destino = fug_obt_pardinamico ('AREA_EMBOZADO') then
              r_gmovi.monto        := nvl(v_tot_compra,0);
           else 
              r_gmovi.monto        := (nvl(v_tot_compra,0)*-1);
           end if;   
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
           ---
           -------------------------------------
           --- MOVIMIENTOS DE ALTA 
           -------------------------------------
           ---
           ---
           v_hor_actual            := pag_gen.fu_obt_sig_segundo(v_hor_actual);
           -- Aumento la secuencia
           v_nro_secuencia         := nvl(v_nro_secuencia,0) + 1;
           -- Genero el movimiento
           r_gmovi.cod_modulo      := r_articulo.cod_modulo;
           r_gmovi.cod_modalidad   := r_articulo.cod_modalidad;
           r_gmovi.cod_oficina     := r_suministro.cod_oficina;
           r_gmovi.nro_cuenta      := null;
           r_gmovi.cod_moneda      := v_cod_mon_local;
           r_gmovi.cod_usuario     := v_cod_usuario;
           r_gmovi.hora            := v_hor_actual;
           r_gmovi.fecha           := v_fec_actual;
           r_gmovi.nro_secuencia   := v_nro_secuencia;
           --
           r_gmovi.fec_valor       := v_fec_actual;
           r_gmovi.cod_tra_padre   := 1300;
           r_gmovi.cod_mod_padre   := r_articulo.cod_modulo;
           r_gmovi.cod_mad_padre   := r_articulo.cod_modalidad;
           r_gmovi.cod_transaccion := v_tra_alta_embozado;
           if fug_obt_pardinamico('AREA_PROCESADORA') = r_suministro.cod_area and p_area_destino = fug_obt_pardinamico ('AREA_EMBOZADO') then
              r_gmovi.monto        := nvl(v_tot_compra,0);
           else 
              r_gmovi.monto        := (nvl(v_tot_compra,0)*-1);
           end if;   
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
          ---Fin de Movimientos para Plásticos de Tarjetas (De Depósito a Embozado)
        else --- Si no se cumple ninguna de las Condiciones del Circuito de Plásticos debe dar Error
              raise_application_error (-20000, 'No puede realizarse la Transferencia solicitada desde Área Origen:'||' '||p_area_origen||' '|| 'y Área Destino:'||' '||p_area_destino||' '||'Verifique.');     
        end if;
      
      elsif r_suministro.cod_oficina = p_ofi_destino and
         fug_obt_tip_implementacion = 2 then
         null;
      elsif p_area_destino in (fug_obt_pardinamico('AREA_PROCESADORA'),fug_obt_pardinamico('AREA_FABRICACION'),fug_obt_pardinamico('AREA_DEPOSITO'),fug_obt_pardinamico('AREA_EMBOZADO')) and r_articulo.cod_tip_articulo <> 14 then 
           raise_application_error (-20000, 'No puede realizarse la Transferencia solicitada desde Área Origen:'||' '||p_area_origen||' '|| 'y Área Destino:'||' '||p_area_destino||' '||'Verifique.');              
      else 
         --------------------------------------
         --- MOVIMIENTOS OFICINA DE DESTINO ---
         --------------------------------------
         v_hor_actual            := pag_gen.fu_obt_sig_segundo(v_hor_actual);
         -- Aumento la secuencia
         v_nro_secuencia         := nvl(v_nro_secuencia,0) + 1;
         -- Genero el movimiento
         r_gmovi.cod_modulo      := r_articulo.cod_modulo;
         r_gmovi.cod_modalidad   := r_articulo.cod_modalidad;
         r_gmovi.cod_oficina     := p_ofi_destino;
         r_gmovi.nro_cuenta      := null;
         r_gmovi.cod_moneda      := v_cod_mon_local;
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
         ---
         -------------------------------------
         --- MOVIMIENTOS DE ALTA 
         -------------------------------------
         ---
         ---
         v_hor_actual            := pag_gen.fu_obt_sig_segundo(v_hor_actual);
         -- Aumento la secuencia
         v_nro_secuencia         := nvl(v_nro_secuencia,0) + 1;
         -- Genero el movimiento
         r_gmovi.cod_modulo      := r_articulo.cod_modulo;
         r_gmovi.cod_modalidad   := r_articulo.cod_modalidad;
         r_gmovi.cod_oficina     := r_suministro.cod_oficina;
         r_gmovi.nro_cuenta      := null;
         r_gmovi.cod_moneda      := v_cod_mon_local;
         r_gmovi.cod_usuario     := v_cod_usuario;
         r_gmovi.hora            := v_hor_actual;
         r_gmovi.fecha           := v_fec_actual;
         r_gmovi.nro_secuencia   := v_nro_secuencia;
         --
         r_gmovi.fec_valor       := v_fec_actual;
         r_gmovi.cod_tra_padre   := 1300;
         r_gmovi.cod_mod_padre   := r_articulo.cod_modulo;
         r_gmovi.cod_mad_padre   := r_articulo.cod_modalidad;
         r_gmovi.cod_transaccion := r_articulo.cod_tra_alta;
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
        
      end if;
   end if;
end;
/

