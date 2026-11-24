CREATE OR REPLACE PROCEDURE IT.PRF_CIE_REVALUO (
  p_fec_proceso af_coe_revaluos.fec_proceso%type,
  p_tipo_coe    af_coe_revaluos.tipo%type)
is
  -- Datos para generar el movimiento
  v_fec_actual        date         := pag_cal.fu_obt_fec_actual(13); -- fecha de hoy
  v_hor_actual        varchar2(08) := to_char(sysdate,'HH24:MI:SS'); -- Hora actual
  v_cod_usuario       varchar2(10) := upper(user);                   -- usuario
  v_nro_secuencia     number(3)    := 0;                             -- secuencia del mov.
  v_vez               char(1)      := 'N';
  r_articulo          af_articulos%rowtype;
  r_gmovi             ge_movimientos%rowtype;
  v_contador          number;
  v_existe            char(1)      := 'N';

  v_dep_mensual       af_bienes.dep_mensual%type;
  v_dep_mensual_normal af_bienes.dep_mensual%type;
  v_rev_depreciacion  af_bienes.rev_depreciacion%type;
  v_revaluo           af_bienes.rev_actual%type;
  v_rev_val_neto      af_bienes.rev_actual%type;
  --
  v_cal_ipc_revaluo  varchar2(1);
  --
  cursor c_bienes_tmp is
  select *
  from   af_bienes_tmp b
  where nvl(b.dep_actual,0) > 0;
  --
  cursor c_bienes_tmp_nodep is
  select *
  from   af_bienes_tmp b
  where nvl(b.dep_actual,0) = 0;
  --
begin
  begin
    select count(cod_bien)
    into   v_contador
    from   af_bienes_tmp;
  exception
    when no_data_found then
      raise_application_error(-20001,'No existen datos a procesar');
    when too_many_rows then
      raise_application_error(-20002,'Mas de un coeficiente a procesar');
  end;
  if nvl(v_contador,0) = 0 then
      raise_application_error(-20001,'No existen datos a procesar');
  end if;
  ---
  begin pre_ini_aplicacion;pae_cnf.g_cod_modulo:=13;end;
  --Verifico si esta marcado parametro de Revaluo--
  v_cal_ipc_revaluo := nvl(fug_obt_pardinamico('IND_CAL_IPC_REVALUO'),'N');
  --- Verifico que no se haya procesado el coeficiente de revaluo
  begin
    select 'E'
    into   v_vez
    from   af_coe_revaluos
    where  fec_proceso = p_fec_proceso
    and    tipo        = p_tipo_coe
    and    nvl(ind_procesado,'N') = 'N';
  exception
    when no_data_found then
       raise_application_error(-20000,
         'No se pudo obtener el coeficiente de revaluo para el periodo '||to_char(p_fec_proceso,'YYYY/MM'));
  end;
     --- Recorro los bienes a actualizar
    for r_bien in c_bienes_tmp loop
      v_vez := 'S';
      --- Paso el registro actual al Histórico
      PRF_INS_BIEN_HIS(r_bien.cod_bien);
      --- Actualizo el bien

      ---- Comentado para Pruebas KF
     if p_tipo_coe = 'A' then
      update af_bienes
      set    rev_anterior       = r_bien.rev_anterior,
             rev_actual         = r_bien.rev_actual,
             rev_ano_anterior   = r_bien.rev_actual,
             rev_ano_acumulado  = r_bien.rev_ano_acumulado,
             ---
             coeficiente        = r_bien.coeficiente,
             fec_proceso        = r_bien.fec_proceso,
             tip_proceso        = r_bien.tip_proceso,
             ---
             dep_anterior       = r_bien.dep_anterior,
             dep_anual          = r_bien.dep_anual,
             dep_mensual        = r_bien.dep_mensual,
             rev_depreciacion   = r_bien.rev_depreciacion,
             dep_actual         = r_bien.dep_actual,
             dep_acumulada      = r_bien.dep_acumulada,
             dep_mensual_normal = r_bien.dep_mensual_normal,
             dep_ano_Acu_anterior = r_bien.dep_acumulada,
             ---
             val_neto         = r_bien.val_neto
      where  cod_bien         = r_bien.cod_bien;

      else
         update af_bienes
         set    rev_anterior       = r_bien.rev_anterior,
             rev_actual         = r_bien.rev_actual,
             rev_ano_anterior   = r_bien.rev_ano_anterior,
             rev_ano_acumulado  = r_bien.rev_ano_acumulado,
             ---
             coeficiente        = r_bien.coeficiente,
             fec_proceso        = r_bien.fec_proceso,
             tip_proceso        = r_bien.tip_proceso,
             ---
             dep_anterior       = r_bien.dep_anterior,
             dep_anual          = r_bien.dep_anual,
             dep_mensual        = r_bien.dep_mensual,
             rev_depreciacion   = r_bien.rev_depreciacion,
             dep_actual         = r_bien.dep_actual,
             dep_acumulada      = r_bien.dep_acumulada,
             dep_mensual_normal = r_bien.dep_mensual_normal,
             dep_ano_Acu_anterior = r_bien.dep_ano_acu_anterior,
             ---
             val_neto         = r_bien.val_neto
      where  cod_bien         = r_bien.cod_bien;
      end if;
      ---

      ---------------------------
      --- INSERTAR MOVIMIENTO ---
      ---------------------------
      ---
  /*
  || si el tipo es Mensual, los asientos se generan en forma automatica
  || si el tipo es Anual no se inserta el movimiento
  */
    if p_tipo_coe = 'M' then
       v_dep_mensual      := r_bien.dep_mensual_normal;
       v_rev_depreciacion := r_bien.rev_depreciacion;
       v_revaluo          := nvl(r_bien.rev_actual,0) - nvl(r_bien.rev_anterior,0);
    else
       select sum(dep_mensual_normal), sum(rev_depreciacion), sum (nvl(rev_actual,0) - nvl(rev_anterior,0)),               sum(dep_mensual)
       into   v_dep_mensual, v_rev_depreciacion,v_revaluo,v_dep_mensual_normal
       from   af_bienes_his
       where  cod_bien = r_bien.cod_bien
       and    TO_NUMBER(TO_CHAR(fec_proceso,'YYYY')) = TO_NUMBER(TO_CHAR(p_fec_proceso,'YYYY'))
       -- Si el vto de depreciación es dentro del periodo debe sumarizar hasta el mes de vto. CB. 27/12/2013. DYDMR-164
       and    TO_NUMBER(TO_CHAR(fec_vto_depreciacion,'YYYYMM')) >= TO_NUMBER(TO_CHAR(fec_proceso,'YYYYMM'))
       and    tip_proceso = 'M';
        v_dep_mensual        := nvl(r_bien.dep_mensual_normal,0) - nvl(v_dep_mensual,0);
        v_dep_mensual_normal := nvl(r_bien.dep_mensual,0) - nvl(v_dep_mensual_normal,0);
        v_rev_depreciacion   := nvl(r_bien.rev_depreciacion,0) - nvl(v_rev_depreciacion,0);
        v_revaluo            := (nvl(r_bien.rev_actual,0) - nvl(r_bien.rev_anterior,0)); /*- nvl(v_revaluo,0);*/
    end if;

   if TO_NUMBER(TO_CHAR(p_fec_proceso,'YYYYMM')) <> TO_NUMBER(TO_CHAR(r_bien.fec_compra,'YYYYMM')) then
      PRF_OBT_ARTICULO(r_bien.cod_articulo, r_articulo);
      ---
      ------------------------------
      --- DEPRECIACION EJERCICIO ---
      ------------------------------
      ---

   --- Si el Proceso es Mensual ---
   if p_tipo_coe = 'M' then
     /* Se debe realizar la validación del Revalúo actual - Depreciación Acumulada > 1 ó Fecha de Vto. de Depreciación >= y Revalúo actual - Depreciación Acumulada > 1 */
      if  nvl(r_articulo.cod_tra_depreciacion,0) <> 0
      and nvl(r_articulo.ind_depreciacion,'N') = 'S' /*and r_bien.coeficiente <> 0*/ then
        v_hor_actual            := pag_gen.fu_obt_sig_segundo(v_hor_actual);
        -- Aumento la secuencia
        if v_nro_secuencia  = 999 then
           v_nro_secuencia := 1;
        else
           v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
        end if;
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
        r_gmovi.cod_transaccion := r_articulo.cod_tra_depreciacion;
        --r_gmovi.monto           := v_dep_mensual;
        r_gmovi.monto           := r_bien.dep_actual;
        --------------------------------------------
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
      end if;

      ---
      ----------------------------------
      --- DEPRECIACION ACELERADA
      ----------------------------------
      ---
      if  nvl(r_articulo.cod_tra_dep_acelerada,0) <> 0
      and nvl(r_articulo.ind_depreciacion,'N') = 'S' and r_articulo.ano_depreciacion > r_articulo.ano_dep_acelerado and r_bien.coeficiente <> 0 then
        v_hor_actual            := pag_gen.fu_obt_sig_segundo(v_hor_actual);
        -- Aumento la secuencia
        if v_nro_secuencia  = 999 then
           v_nro_secuencia := 1;
        else
           v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
        end if;
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
        r_gmovi.cod_transaccion := r_articulo.cod_tra_dep_acelerada;
        --r_gmovi.monto           := nvl(r_bien.dep_mensual,0) - nvl(r_bien.dep_mensual_normal,0);
        r_gmovi.monto           := r_bien.dep_actual;
        ------
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
      end if;


      ---
      ----------------------------------
      --- REVALUO DE LA DEPRECIACION ---
      ----------------------------------
      ---
      if nvl(r_articulo.cod_tra_dep_acumulada,0) <> 0 and r_bien.coeficiente <> 0 and v_cal_ipc_revaluo = 'S' then
        v_hor_actual            := pag_gen.fu_obt_sig_segundo(v_hor_actual);
        -- Aumento la secuencia
        if v_nro_secuencia  = 999 then
           v_nro_secuencia := 1;
        else
           v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
        end if;
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
        r_gmovi.cod_transaccion := r_articulo.cod_tra_dep_acumulada;
        r_gmovi.monto           := v_rev_depreciacion;
        r_gmovi.nro_documento   := r_bien.cod_bien;
        r_gmovi.cod_tasa        := null;
        r_gmovi.val_tasa        := null;
        r_gmovi.cotizacion      := null;
        r_gmovi.cod_ofi_origen  := r_bien.cod_oficina;
        r_gmovi.emi_aviso       := 'N';
        r_gmovi.concepto        :=  substr(r_bien.descripcion,1,35);
        r_gmovi.estado          := 'N';
        r_gmovi.reversado       := 'N';
        r_gmovi.nro_caja        := null;
        r_gmovi.cod_rubro       := NULL;
        r_gmovi.tip_mov_rubro   := 'C';--CREDITO
        PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, 'N'); -- no es nocturno
      end if;
      ---
      ---------------
      --- REVALUO ---
      ---------------
      ---
      if  nvl(r_articulo.cod_tra_revaluo,0) <> 0
      and nvl(r_articulo.ind_revaluo,'N') = 'S' and r_bien.coeficiente <> 0  and v_cal_ipc_revaluo = 'S' then
        v_hor_actual            := pag_gen.fu_obt_sig_segundo(v_hor_actual);
        -- Aumento la secuencia
        if v_nro_secuencia  = 999 then
           v_nro_secuencia := 1;
        else
           v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
        end if;
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
        r_gmovi.cod_transaccion := r_articulo.cod_tra_revaluo;
        r_gmovi.monto           := v_revaluo;
        r_gmovi.nro_documento   := r_bien.cod_bien;
        r_gmovi.cod_tasa        := null;
        r_gmovi.val_tasa        := null;
        r_gmovi.cotizacion      := null;
        r_gmovi.cod_ofi_origen  := r_bien.cod_oficina;
        r_gmovi.emi_aviso       := 'N';
        r_gmovi.concepto        :=  substr(r_bien.descripcion,1,35);
        r_gmovi.estado          := 'N';
        r_gmovi.reversado       := 'N';
        r_gmovi.nro_caja        := null;
        r_gmovi.cod_rubro       := NULL;
        r_gmovi.tip_mov_rubro   := 'C';--CREDITO
        PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, 'N'); -- no es nocturno
      end if;
   elsif p_tipo_coe = 'A' then
      if  nvl(r_articulo.cod_tra_depreciacion,0) <> 0
      and nvl(r_articulo.ind_depreciacion,'N') = 'S'  and r_bien.coeficiente <> 0 then
        v_hor_actual            := pag_gen.fu_obt_sig_segundo(v_hor_actual);
        -- Aumento la secuencia
        if v_nro_secuencia  = 999 then
           v_nro_secuencia := 1;
        else
           v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
        end if;
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
        r_gmovi.cod_transaccion := r_articulo.cod_tra_depreciacion;
        r_gmovi.monto           := nvl(v_dep_mensual,0);
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
      end if;

      ---
      ----------------------------------
      --- DEPRECIACION ACELERADA
      ----------------------------------
      ---

      if  nvl(r_articulo.cod_tra_dep_acelerada,0) <> 0
      and nvl(r_articulo.ind_depreciacion,'N') = 'S' and r_articulo.ano_depreciacion > r_articulo.ano_dep_acelerado   and r_bien.coeficiente <> 0 then
        v_hor_actual            := pag_gen.fu_obt_sig_segundo(v_hor_actual);
        -- Aumento la secuencia
        if v_nro_secuencia  = 999 then
           v_nro_secuencia := 1;
        else
           v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
        end if;
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
        r_gmovi.cod_transaccion := r_articulo.cod_tra_dep_acelerada;
        r_gmovi.monto           := nvl(v_dep_mensual_normal,0) - nvl(v_dep_mensual,0);
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
      end if;


      ---
      ----------------------------------
      --- REVALUO DE LA DEPRECIACION ---
      ----------------------------------
      ---
      if nvl(r_articulo.cod_tra_dep_acumulada,0) <> 0  and r_bien.coeficiente <> 0 then
        v_hor_actual            := pag_gen.fu_obt_sig_segundo(v_hor_actual);
        -- Aumento la secuencia
        if v_nro_secuencia  = 999 then
           v_nro_secuencia := 1;
        else
           v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
        end if;
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
        r_gmovi.cod_transaccion := r_articulo.cod_tra_dep_acumulada;
        r_gmovi.monto           := v_rev_depreciacion;
        r_gmovi.nro_documento   := r_bien.cod_bien;
        r_gmovi.cod_tasa        := null;
        r_gmovi.val_tasa        := null;
        r_gmovi.cotizacion      := null;
        r_gmovi.cod_ofi_origen  := r_bien.cod_oficina;
        r_gmovi.emi_aviso       := 'N';
        r_gmovi.concepto        :=  substr(r_bien.descripcion,1,35);
        r_gmovi.estado          := 'N';
        r_gmovi.reversado       := 'N';
        r_gmovi.nro_caja        := null;
        r_gmovi.cod_rubro       := NULL;
        r_gmovi.tip_mov_rubro   := 'C';--CREDITO
        PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, 'N'); -- no es nocturno
      end if;
      ---
      ---------------
      --- REVALUO ---
      ---------------
      ---
      if  nvl(r_articulo.cod_tra_revaluo,0) <> 0
      and nvl(r_articulo.ind_revaluo,'N') = 'S'  and r_bien.coeficiente <> 0 and v_cal_ipc_revaluo = 'S' then
        v_hor_actual            := pag_gen.fu_obt_sig_segundo(v_hor_actual);
        -- Aumento la secuencia
        if v_nro_secuencia  = 999 then
           v_nro_secuencia := 1;
        else
           v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
        end if;
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
        r_gmovi.cod_transaccion := r_articulo.cod_tra_revaluo;
        r_gmovi.monto           := v_revaluo;
        r_gmovi.nro_documento   := r_bien.cod_bien;
        r_gmovi.cod_tasa        := null;
        r_gmovi.val_tasa        := null;
        r_gmovi.cotizacion      := null;
        r_gmovi.cod_ofi_origen  := r_bien.cod_oficina;
        r_gmovi.emi_aviso       := 'N';
        r_gmovi.concepto        :=  substr(r_bien.descripcion,1,35);
        r_gmovi.estado          := 'N';
        r_gmovi.reversado       := 'N';
        r_gmovi.nro_caja        := null;
        r_gmovi.cod_rubro       := NULL;
        r_gmovi.tip_mov_rubro   := 'C';--CREDITO
        PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, 'N'); -- no es nocturno
      end if;
   end if;
      ---
 end if;
end loop;
    ---
-------
for r_bien in c_bienes_tmp_nodep loop
      v_vez := 'S';
      --- Paso el registro actual al Histórico
      PRF_INS_BIEN_HIS(r_bien.cod_bien);
      --- Actualizo el bien

      ---- Comentado para Pruebas KF
     if p_tipo_coe = 'A' then
      update af_bienes
      set    rev_anterior       = r_bien.rev_anterior,
             rev_actual         = r_bien.rev_actual,
             rev_ano_anterior   = r_bien.rev_actual,
             rev_ano_acumulado  = r_bien.rev_ano_acumulado,
             ---
             coeficiente        = r_bien.coeficiente,
             fec_proceso        = r_bien.fec_proceso,
             tip_proceso        = r_bien.tip_proceso,
             ---
             dep_anterior       = r_bien.dep_anterior,
             dep_anual          = r_bien.dep_anual,
             dep_mensual        = r_bien.dep_mensual,
             rev_depreciacion   = r_bien.rev_depreciacion,
             dep_actual         = r_bien.dep_actual,
             dep_acumulada      = r_bien.dep_acumulada,
             dep_mensual_normal = r_bien.dep_mensual_normal,
             dep_ano_Acu_anterior = r_bien.dep_acumulada,
             ---
             val_neto         = r_bien.val_neto
      where  cod_bien         = r_bien.cod_bien;

      else
         update af_bienes
         set    rev_anterior       = r_bien.rev_anterior,
             rev_actual         = r_bien.rev_actual,
             rev_ano_anterior   = r_bien.rev_ano_anterior,
             rev_ano_acumulado  = r_bien.rev_ano_acumulado,
             ---
             coeficiente        = r_bien.coeficiente,
             fec_proceso        = r_bien.fec_proceso,
             tip_proceso        = r_bien.tip_proceso,
             ---
             dep_anterior       = r_bien.dep_anterior,
             dep_anual          = r_bien.dep_anual,
             dep_mensual        = r_bien.dep_mensual,
             rev_depreciacion   = r_bien.rev_depreciacion,
             dep_actual         = r_bien.dep_actual,
             dep_acumulada      = r_bien.dep_acumulada,
             dep_mensual_normal = r_bien.dep_mensual_normal,
             dep_ano_Acu_anterior = r_bien.dep_ano_acu_anterior,
             ---
             val_neto         = r_bien.val_neto
      where  cod_bien         = r_bien.cod_bien;
      end if;
end loop;
-------
    if v_vez <> 'S' then
       raise_application_error(-20000,
         'No se existen datos a procesar. El coeficiente ya fue procesado.');
    end if;


    --- Limpio la tabla temporal
    delete from af_bienes_tmp; --Mientras comentado KF
    ---
    ---Generar Asientos Automáticos de Activo Fijo
     --- Se comenta la generacion de asientos automaticos ya que va a tomar del proceso general del cierre PRA_CON_TRANSACCION y PRA_GEN_ASIENTOS
     --prf_gen_asi_automaticos;


    ---Unificar Asientos
       ---Se comenta la generacion de unificacion de asientos ya que no se tiene implementado el Módulo de Contabilidad
      --prf_uni_asientos;
    ---
   --end if;

  --- Actualizo el coeficiente
  update af_coe_revaluos
  set    ind_procesado = 'S'
  where  fec_proceso = p_fec_proceso
  and    tipo        = p_tipo_coe;
  ---
exception
  when others then
      if sqlcode <= -20000 then
         raise;
      else
          raise_application_error(-20000,
          'Error al generar el Proceso de Revalúo.' ||sqlerrm);
      end if;
end;
/

