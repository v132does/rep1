CREATE OR REPLACE PROCEDURE IT.prp_obt_tran_fideicomiso(p_modulo          IN pr_cta_prestamos.cod_modulo%type,
                                                        p_concepto        IN pr_cob_prioridades.concepto%type,
                                                        p_estado          IN pr_cta_prestamos.estado%type,
                                                        p_cod_modalidad   IN pr_cta_prestamos.cod_modalidad%type,
                                                        p_tipo            IN pr_cta_prestamos.tipo%type,
                                                        p_nro_cuenta      IN pr_cta_prestamos.nro_cuenta%type,
                                                        p_cod_transaccion OUT ge_transacciones.cod_transaccion%type, -- OUT,
                                                        p_descripcion     OUT ge_movimientos.concepto%type -- OUT
                                                        ) IS

  /* proceso que retorna la transaccion y el concepto para el movimiento, que se deben usar por pase a fideicomiso,
  teniendo en cuenta las condiciones del prestamo*/
  /*
   p_concepto      -> Capital(CA)/
   p_modulo        -> Modulo del prestamo (6) para prestamos, (15) para operaciones vencidas 
   p_estado        -> Estado actual del prestamo
   p_cod_modalidad -> Modalidad con la cual va entrar a fideicomiso
   p_tipo          -> P plazo fijo / D descuento documento / A amortizable
   p_nro_cuenta    -> Nro de cuenta del prestamo
   P_TIP_INTERES   -> A adelantado / V vencido
  */
  v_parametro      ge_parametros.parametro%type; 
  v_sub_modalidad  ge_par_dinamicos.cod_sub_modalidad%type;
BEGIN
  -- configuracion de transaccion para prestamos
  if p_cod_modalidad = 676 then
  v_parametro := 'MOD_DES_FI_DDCHE';
  elsif p_cod_modalidad = 675 then 
    v_parametro := 'MOD_DES_FI_PREST';
  elsif p_cod_modalidad = 152 then 
    v_parametro := 'MOD_DES_FI_VEN';
  end if;
    
  if v_parametro is not null then 
    select d.cod_sub_modalidad
     into v_sub_modalidad 
    from ge_par_dinamicos d
    where d.parametro = v_parametro
      and d.cod_modalidad = p_cod_modalidad;
  end if;
  if p_modulo = 6 then
    /************
        CAPITAL 
    **************/
    if p_concepto = 'CA' then
      --modalidad destino para prestamos
      
      if p_cod_modalidad = fug_obt_pardinamico('MOD_DES_FI_PREST',p_modulo,p_cod_modalidad,null, null,v_sub_modalidad) then
        --capital vigente - plazo fijo 
        if p_estado IN ('C') and p_tipo = 'P' then
          p_cod_transaccion := 983;
          p_descripcion     := 'TRANSF.CAPITAL VIG. A FIDEICOMISO - PLAZO FIJO';
        end if;
        --capital vigente - amortizable
        if p_estado IN ('C') and p_tipo = 'A' then
          p_cod_transaccion := 984;
          p_descripcion     := 'TRANSF.CAPITAL VIG.A FIDEICOMISO - AMORTIZABLE';
        end if;
        --capital vigente -  Descto. de Documentos
        if p_estado IN ('C') and p_tipo = 'D' then
          p_cod_transaccion := 984; --se considera como amortizable 
          p_descripcion     := 'TRANSF.CAPITAL VIG.A FIDEICOMISO - AMORTIZABLE';
        end if;
        --capital vencida
        if p_estado IN ('V') then
          p_cod_transaccion := 985;
          p_descripcion     := 'TRANSF.CAPITAL VENCIDA A FIDEICOMISO';
        end if;
        --capital en gestion
        if p_estado IN ('G') then
          p_cod_transaccion := 986;
          p_descripcion     := 'TRANSF.CAPITAL EN GESTION FIDEICOMISO';
        end if;
        --capital moroso
        if p_estado IN ('M', 'I') then
          -- considerar el inrecuperable?
          p_cod_transaccion := 987;
          p_descripcion     := 'TRANSF.CAPITAL MOROSA A FIDEICOMISO';
        end if;
      elsif p_cod_modalidad = fug_obt_pardinamico('MOD_DES_FI_DDCHE',p_modulo,p_cod_modalidad,null, null,v_sub_modalidad) then
        --Modalidad destino para prestamos desc. de cheques
        --capital vigente - plazo fijo 
        if p_estado IN ('C') and p_tipo = 'P' then
          p_cod_transaccion := 983;
          p_descripcion     := 'TRANSF.CAPITAL VIG. A FIDEICOMISO - PLAZO FIJO';
        end if;
        --capital vigente - amortizable
        if p_estado IN ('C') and p_tipo = 'A' then
          p_cod_transaccion := 984;
          p_descripcion     := 'TRANSF.CAPITAL VIG.A FIDEICOMISO - AMORTIZABLE';
        end if;
        --capital vigente -  Descto. de Documentos
        if p_estado IN ('C') and p_tipo = 'D' then
          p_cod_transaccion := 984; --se considera como amortizable 
          p_descripcion     := 'TRANSF.CAPITAL VIG.A FIDEICOMISO - AMORTIZABLE';
        end if;
        --capital vencida
        if p_estado IN ('V') then
          p_cod_transaccion := 985;
          p_descripcion     := 'TRANSF.CAPITAL VENCIDA A FIDEICOMISO';
        end if;
        --capital en gestion
        if p_estado IN ('G') then
          p_cod_transaccion := 986;
          p_descripcion     := 'TRANSF.CAPITAL EN GESTION FIDEICOMISO';
        end if;
        --capital moroso
        if p_estado IN ('M', 'I') then
          -- considerar el inrecuperable?
          p_cod_transaccion := 987;
          p_descripcion     := 'TRANSF.CAPITAL MOROSA A FIDEICOMISO';
        end if;
      end if;
      /***********************
          INTERESES A COBRAR 
      **************************/
    elsif p_concepto = 'IN' THEN
      --Modalidad destino para prestamos
      if p_cod_modalidad = fug_obt_pardinamico('MOD_DES_FI_PREST',p_modulo,p_cod_modalidad,null, null,v_sub_modalidad) then
        --vigente  a fideicomiso
        if p_estado IN ('C') then
          p_cod_transaccion := 988;
          p_descripcion     := 'TRASP.INT.TIPO 82 DOC. VIG. A FIDEICOMISO';
        end if;
        -- mora a fideicomiso
        if p_estado IN ('M', 'I') then
          p_cod_transaccion := 989;
          p_descripcion     := 'TRASP.INT.TIPO 82 DOC. DE MOR. A FIDEICOMISO';
        end if;
        -- gestion a fideicomiso
        if p_estado IN ('G') then
          p_cod_transaccion := 990;
          p_descripcion     := 'TRASP.INT.TIPO 82 DOC. DE GESTION A FIDEICOMISO';
        end if;
        -- vencida a fideicomiso
        if p_estado IN ('V') then
          p_cod_transaccion := 991;
          p_descripcion     := 'TRASP.INT.TIPO 82 DOC. DE VENC. A FIDEICOMISO';
        end if;
      elsif p_cod_modalidad = fug_obt_pardinamico('MOD_DES_FI_DDCHE',p_modulo,p_cod_modalidad,null, null,v_sub_modalidad) then
        --modalidad destino para descuento de cheques
        --vigente  a fideicomiso
        if p_estado IN ('C') then
          p_cod_transaccion := 988;
          p_descripcion     := 'TRASP.INT.TIPO 82 DOC. VIG. A FIDEICOMISO';
        end if;
        -- mora a fideicomiso
        if p_estado IN ('M', 'I') then
          p_cod_transaccion := 989;
          p_descripcion     := 'TRASP.INT.TIPO 82 DOC. DE MOR. A FIDEICOMISO';
        end if;
        -- gestion a fideicomiso
        if p_estado IN ('G') then
          p_cod_transaccion := 990;
          p_descripcion     := 'TRASP.INT.TIPO 82 DOC. DE GESTION A FIDEICOMISO';
        end if;
        -- vencida a fideicomiso
        if p_estado IN ('V') then
          p_cod_transaccion := 991;
          p_descripcion     := 'TRASP.INT.TIPO 82 DOC. DE VENC. A FIDEICOMISO';
        end if;
      end if;
      /***********************
       INTERESES A DEVENGAR 
      **************************/
    elsif p_concepto = 'ID' THEN
    
      if p_cod_modalidad = fug_obt_pardinamico('MOD_DES_FI_PREST',p_modulo,p_cod_modalidad,null, null,v_sub_modalidad) then
        -- vigente a fideicomiso
        if p_estado IN ('C') then
          p_cod_transaccion := 992;
          p_descripcion     := 'TRANSP.INT.TIPO 94 DOC.DE VIG. A FIDEICOMISO';
        end if;
        -- vencida a fideicomiso
        if p_estado IN ('V') then
          p_cod_transaccion := 993;
          p_descripcion     := 'TRASP.INT.TIPO 94 DOC.DE VENC. A FIDEICOMISO';
        
        end if;
        -- gestion a fideicomiso
        if p_estado IN ('G') then
          p_cod_transaccion := 994;
          p_descripcion     := 'TRASP.INT.TIPO 94 DOC.DE GESTION A FIDEICOMISO';
        end if;
        -- mora a fideicomiso
        if p_estado IN ('M', 'I') then
          p_cod_transaccion := 995;
          p_descripcion     := ' TRASP.INT.TIPO 94 DOC.DE MOROSO A FIDEICOMISO';
        end if;
      elsif p_cod_modalidad = fug_obt_pardinamico('MOD_DES_FI_DDCHE',p_modulo,p_cod_modalidad,null, null,v_sub_modalidad) then
        -- vigente a fideicomiso
        if p_estado IN ('C') then
          p_cod_transaccion := 992;
          p_descripcion     := 'TRANSP.INT.TIPO 94 DOC.DE VIG. A FIDEICOMISO';
        end if;
        -- vencida a fideicomiso
        if p_estado IN ('V') then
          p_cod_transaccion := 993;
          p_descripcion     := 'TRASP.INT.TIPO 94 DOC.DE VENC. A FIDEICOMISO';
        end if;
        -- gestion a fideicomiso
        if p_estado IN ('G') then
          p_cod_transaccion := 994;
          p_descripcion     := 'TRASP.INT.TIPO 94 DOC.DE GESTION A FIDEICOMISO';
        end if;
        -- mora a fideicomiso
        if p_estado IN ('M', 'I') then
          p_cod_transaccion := 995;
          p_descripcion     := 'TRASP.INT.TIPO 94 DOC.DE MOROSO A FIDEICOMISO';
        end if;
      end if;
      /*****************
           PREVISIONES 
      ******************/
    elsif p_concepto = 'PR' THEN
      if p_cod_modalidad = fug_obt_pardinamico('MOD_DES_FI_PREST',p_modulo,p_cod_modalidad,null, null,v_sub_modalidad) then
        p_cod_transaccion := 996;
          p_descripcion     := 'TRANSF. PREVISION A FIDEICOMISO';
      elsif p_cod_modalidad = fug_obt_pardinamico('MOD_DES_FI_DDCHE',p_modulo,p_cod_modalidad,null, null,v_sub_modalidad) then
        p_cod_transaccion := 996;
          p_descripcion     := 'TRANSF. PREVISION A FIDEICOMISO';
      end if;
      /*****************
           INTERES EN SUSPENSO 
      ******************/
    elsif p_concepto = 'IS' THEN
      if p_cod_modalidad = fug_obt_pardinamico('MOD_DES_FI_PREST',p_modulo,p_cod_modalidad,null, null,v_sub_modalidad) then
        p_cod_transaccion := 997;
        p_descripcion     := 'TRANSF. DEV. EN SUSPENSO A FIDEICOMISO';
      elsif p_cod_modalidad = fug_obt_pardinamico('MOD_DES_FI_DDCHE',p_modulo,p_cod_modalidad,null, null,v_sub_modalidad) then
        p_cod_transaccion := 997;
        p_descripcion     := 'TRANSF. DEV. EN SUSPENSO A FIDEICOMISO';
      end if;
    end if;
  
  elsif p_modulo = 15 then
    -- configuracion de transaccion operaciones vencidas 
  
    if p_concepto = 'CA' then
      /*****************
        CAPITAL
      *****************/
      if p_cod_modalidad = fug_obt_pardinamico('MOD_DES_FI_VEN',p_modulo,p_cod_modalidad,null, null,v_sub_modalidad) then
        p_cod_transaccion := 983;
         p_descripcion     :='TRANSF.CAPITAL A FIDEICOMISO';
      end if;
    elsif p_concepto = 'PR' THEN
      /*****************
        PREVISIONES 
      *****************/
      if p_cod_modalidad = fug_obt_pardinamico('MOD_DES_FI_VEN',p_modulo,p_cod_modalidad,null, null,v_sub_modalidad) then
        p_cod_transaccion := 996;
         p_descripcion     :='TRANSF. PREVISION A FIDEICOMISO';
      end if;
    end if;
  end if;
  --- Para que de error de transaccion si no recupera nada
  IF p_cod_transaccion IS NULL THEN
    p_cod_transaccion := -1;
  END IF;

EXCEPTION
  WHEN OTHERS THEN
    raise_application_error(-20000,
                            'Obt.Trans. Cta.' || p_nro_cuenta || ' Est.' ||
                            p_estado || ' Tipo ' || p_tipo || ' Int.' || '-' ||
                            SQLERRM);
END;
/

