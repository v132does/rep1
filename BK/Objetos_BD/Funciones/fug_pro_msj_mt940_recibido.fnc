CREATE OR REPLACE FUNCTION IT.FUG_PRO_MSJ_MT940_RECIBIDO RETURN NUMBER IS
  CURSOR mensaje IS
    SELECT TRIM(texto) texto, nro_orden
      FROM ge_mt940_tmp
     ORDER BY nro_orden;
  --
  r_gextra ge_ext_swift%ROWTYPE;
  r_gexdet ge_ext_swift_det%ROWTYPE;
  msj      mensaje%ROWTYPE;
  --
  v_can_reg_procesado  NUMBER(6) := 0;
  v_cabecera           VARCHAR2(1) := 'N';
  v_registro           VARCHAR2(1000);
  v_cnt_detalles       NUMBER(10) := 0;
  v_hora               VARCHAR2(10);
  v_sal_fin_disponible ge_ext_swift.sal_disponible%TYPE := 0;
  v_error              varchar2(200);
  v_formato varchar2(240);
  v_nro_cta_bancaria   cc_cta_bancarias.nro_cta_bancaria%type;
  v_monto varchar2(100);
  
  --RE DE-1015 -- variables
  v_tag_86 NUMBER(3) DEFAULT 0;  -- PARA CONTROLAR SI CORRESPONDE AL TAG :86:
  v_tag_61 NUMBER(3) DEFAULT 0;
  insert_cabecera exception; --RE DE-1015 variable de exception utilizado en el procedimineto local lp_ins_ext_swift
  insert_detalle exception; --RE DE-1015 variable de exception utilizado en el procedimineto local lp_ins_ext_swift_det
  verror VARCHAR2(100);     --RE DE-1015 variable para guardar el error
  
  --
  PROCEDURE lp_ins_ext_swift IS
  BEGIN
    IF v_cabecera = 'N' THEN
      -- Cantidad de Registros
      v_can_reg_procesado := v_can_reg_procesado + 1;

      INSERT INTO ge_ext_swift
        (nro_ref_externa,
         cod_swi_origen,
         cod_swi_destino,
         nro_cuenta,
         nro_mensaje,
         nro_secuencia,
         tip_saldo,
         fec_mensaje,
         cod_moneda,
         sal_anterior,
         sal_actual,
         sal_disponible)
      VALUES
        (r_gextra.nro_ref_externa,
         r_gextra.cod_swi_origen,
         r_gextra.cod_swi_destino,
         r_gextra.nro_cuenta,
         r_gextra.nro_mensaje,
         r_gextra.nro_secuencia,
         r_gextra.tip_saldo,
         r_gextra.fec_mensaje,
         r_gextra.cod_moneda,
         r_gextra.sal_anterior,
         r_gextra.sal_actual,
         r_gextra.sal_disponible);
    ELSE
      UPDATE ge_ext_swift
         SET sal_actual     = r_gextra.sal_actual,
             sal_disponible = r_gextra.sal_disponible,
             tip_saldo      = r_gextra.tip_saldo,
             fec_mensaje    = r_gextra.fec_mensaje
       WHERE nro_ref_externa = r_gextra.nro_ref_externa;

    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      verror := substr(SQLERRM,1,100);
      RAISE insert_cabecera;
  END;
  --
  PROCEDURE lp_ins_ext_swift_det IS
  BEGIN
    INSERT INTO ge_ext_swift_det
      (nro_ref_externa,
       nro_orden,
       fec_generacion,
       fec_envio,
       tip_movimiento,
       cod_moneda,
       monto,
       ref_movimiento,
       nro_documento,
       descripcion,
       nro_conciliacion,
       observacion)
    VALUES
      (r_gexdet.nro_ref_externa,
       r_gexdet.nro_orden,
       r_gexdet.fec_generacion,
       r_gexdet.fec_envio,
       r_gexdet.tip_movimiento,
       r_gextra.cod_moneda,
       r_gexdet.monto,
       r_gexdet.ref_movimiento,
       r_gexdet.nro_documento,
       r_gexdet.descripcion,
       r_gexdet.nro_conciliacion,
       r_gexdet.observacion);
       
       --RE DE-1015 27/08/2015 se inicializa las variables de control una vez grabado el registro
       v_tag_61 :=0; 
       v_tag_86 := 0;
  EXCEPTION
    WHEN OTHERS THEN
      verror := substr(SQLERRM,1,100);
      RAISE insert_detalle;
  END;
  
BEGIN
  -- Acepta en esta sesión como separador de decimales la coma.
  pre_cam_for_numerico(',.');
  --------------------------
  -- inicio de la lectura de los datos del mensaje
  FOR msj IN mensaje LOOP
    v_error := null;
    v_hora  := msj.nro_orden;
    -- fin del mensaje, ya se puede cargar los datos de la transferencia
    IF substr(msj.texto, 1, 2) = '-}' THEN
      -- si está registrada la cabecera y tiene detalles debe hacer update de la cabecera con los datos q faltan.
      lp_ins_ext_swift;
      v_cnt_detalles := 0;
      -- El primer Registro Carga con La variable que indica, no Imprimió la cabacera.
      v_cabecera := 'N';
      r_gextra   := NULL;
      r_gexdet   := NULL;
    END IF;
    -- referencia externa
    IF substr(msj.texto, 1, 3) = '{1:' THEN
      r_gextra.cod_swi_origen := substr(msj.texto, 7, 8);
      -- Ejemplo = {2:I103CHASUS33XXXXN}
      r_gextra.cod_swi_destino := substr(msj.texto,
                                         instr(msj.texto, '{2:') + 7,
                                         8);
    ELSIF msj.texto LIKE '%}${1:%' THEN
      r_gextra.cod_swi_origen := substr(msj.texto,
                                        instr(msj.texto, '}${1:') + 8,
                                        8);
      -- Ejemplo = {2:I103CHASUS33XXXXN}
      r_gextra.cod_swi_destino := substr(msj.texto,
                                         instr(msj.texto, '{2:') + 7,
                                         8);
      -- :20 Nro Referencia
    ELSIF substr(msj.texto, 1, 4) = ':20:' THEN
      r_gextra.nro_ref_externa := substr(msj.texto, 5);
      -- :25 Nro. Cuenta
    ELSIF substr(msj.texto, 1, 4) = ':25:' THEN
      /*dydmr-1592  PN 25/02/2015*/
      v_nro_cta_bancaria := substr(msj.texto, 5);
      BEGIN
        SELECT nro_cuenta
          INTO r_gextra.nro_cuenta
          FROM cc_cta_bancarias
         WHERE nro_cta_bancaria = v_nro_cta_bancaria;--r_gextra.nro_cuenta;
      EXCEPTION
        WHEN OTHERS THEN
          raise_application_error(-20000,
                                  'Error al buscar Cuenta Bancaria Nro. ' ||
                                  r_gextra.nro_cuenta || '. ' || SQLERRM);
      END;
      -- :28C Nro. de Mensaje/Nro. de Secuencia
    ELSIF substr(msj.texto, 1, 5) = ':28C:' THEN
      select val_maximo
      into v_formato
      from ba_cod_referencias
      where val_minimo = '28C'
      and dominio = 'MSJ_MT940';

      /*dydmr-1592  FM 18/02/2015*/
      v_error := fug_val_for_msj_swts(v_formato,
                                      substr(msj.texto, 6),
                                      ':28C:');
      if v_error is null then
        if instr(msj.texto, '/') > 0 then
          r_gextra.nro_mensaje   := substr(msj.texto,
                                           instr(msj.texto, 'C:') + 2,
                                           instr(msj.texto, '/') -
                                           (instr(msj.texto, 'C:') + 2)); ---substr(msj.texto, 6, 5);

          r_gextra.nro_secuencia := substr(msj.texto,
                                           instr(msj.texto, '/') + 1);
          
          r_gextra.nro_ref_externa := r_gextra.nro_ref_externa||'-'||r_gextra.nro_mensaje||'-'||r_gextra.nro_secuencia; 
          
        else
          --substr(msj.texto, 12);
          r_gextra.nro_mensaje   := substr(msj.texto,
                                           instr(msj.texto, 'C:') + 2);

          r_gextra.nro_secuencia := null;
          r_gextra.nro_ref_externa := r_gextra.nro_ref_externa||'-'||r_gextra.nro_mensaje||'-'||r_gextra.nro_secuencia; 
      
        end if;
      else
        raise_application_error(-20002, v_error);
      end if;

      -- :60F Saldo día Anterior
    ELSIF substr(msj.texto, 1, 3) = ':60' THEN
      r_gextra.sal_anterior := ltrim(rtrim(substr(msj.texto, 16)));
      r_gextra.cod_moneda   := substr(msj.texto, 13, 3);
      --
      IF r_gextra.cod_moneda = 'PYG' THEN
        r_gextra.cod_moneda := 'GS';
      END IF;
      --se agrega la fecha a la referencia externa - dydmr-3813
      r_gextra.nro_ref_externa :=trim(rtrim(substr(msj.texto, 7,6)))||'-'||r_gextra.nro_ref_externa; 
      -- :61F Inserta Detalle
    ELSIF substr(msj.texto, 1, 3) = ':61' /*OR substr(msj.texto,1,5) = 'BEN:'*/ 
      THEN
      -- BEN: Beneficiario
      --if substr(msj.texto,1,3) = ':61' then
      ---verifica que haya entrado anteriormente
      --RE DE-1015 -----------------
      IF v_tag_61 > 0 THEN
        IF r_gexdet.ref_movimiento IS NOT NULL THEN --RE DE-1015 se inserta el detalle
           lp_ins_ext_swift_det;
           r_gexdet.observacion := NULL;
        END IF;
      END IF;
      v_tag_61 := 1;--re DE-1015 27/08/2015 se marca como ingresado al tag 61:
      ------------------------------
      r_gexdet.descripcion     := substr(msj.texto, 5);
      r_gexdet.nro_ref_externa := r_gextra.nro_ref_externa;
      v_cnt_detalles           := v_cnt_detalles + 1;
      --
      r_gexdet.nro_orden := v_cnt_detalles;
      --
      v_registro              := substr(msj.texto, 5);
      r_gexdet.fec_generacion := to_date(substr(v_registro, 1, 6), 'yymmdd');
      /*DYDMR-1593*/
      if substr(msj.texto, 11, 1) in ('C', 'D', 'R') THEN
        V_REGISTRO := trim(substr(v_registro, 3, 4)) ||
                      substr(v_registro, 7);
      else
        v_registro := substr(v_registro, 7);
      end if;
      r_gexdet.fec_envio      := substr(v_registro, 1, 4);
      v_registro              := substr(v_registro, 5);
      r_gexdet.tip_movimiento := substr(v_registro, 1, 1);
      
      -- dydmr-1592  PN  Si no es numérico, entonces toma 2 caracteres, debido a que el campo Funds code es obcional
      
      if fug_val_es_numerico(substr(v_registro, 2, 1)) = 'S' then
         v_registro := substr(v_registro, 1);
      else
         v_registro := substr(v_registro, 2);
      end if;
      --
      r_gexdet.cod_moneda     := substr(v_registro, 1, 1);
      v_registro              := substr(v_registro, 2);

      /*r_gexdet.monto          := ltrim(rtrim(substr(v_registro,
                                                    1,
                                                    instr(v_registro, ',') + 2)));*/

      /*dydmr-1592  PN 25/02/2015*/
      v_monto := ltrim(rtrim(substr(v_registro,1,instr(v_registro, ',') + 2)));
      if  fug_val_es_numerico(v_monto) = 'S' then
        r_gexdet.monto := v_monto;
      else
        v_monto := ltrim(rtrim(substr(v_registro,1,instr(v_registro, ',') + 1)));
        if  fug_val_es_numerico(v_monto) = 'S' then
          r_gexdet.monto := v_monto;
        else              
          r_gexdet.monto:= ltrim(rtrim(substr(v_registro,1,instr(v_registro, ',') -1)));
         end if;
      end if;


      v_registro              := substr(v_registro,
                                        instr(v_registro, ',') + 3);
      if instr(v_registro, '//') = 0 then
        r_gexdet.ref_movimiento := v_registro;
      else
        r_gexdet.ref_movimiento := substr(v_registro,
                                          1,
                                          instr(v_registro, '//') - 1);
      end if;
      v_registro             := substr(v_registro, instr(v_registro, '//'));
      r_gexdet.nro_documento := substr(v_registro, 3);
      --
      IF v_cabecera = 'N' THEN
        -- Inicializa el contador de detalles
        r_gextra.sal_actual     := 0;
        r_gextra.sal_disponible := 0;
        lp_ins_ext_swift;
        -- Carga la variable que indica que Imprimió la Cabecera.
        v_cabecera := 'S';
      END IF;
      --
      /*ELSE
        r_gexdet.descripcion := substr(msj.texto,5);
      END IF;*/
      /*IF r_gexdet.ref_movimiento IS NOT NULL THEN --RE DE-1015 Se comenta para que se inserte despues de leer el tag :86 y :BEN
        lp_ins_ext_swift_det;
      END IF;*/
    -- :62F Saldo Actual
    ELSIF substr(msj.texto, 1, 3) = ':62' THEN
      --RE DE-1015 27/08/2015
      IF v_tag_61 > 0 THEN 
         --se asigna referencia externa de la cabecera al detalle - dydmr-3813
        r_gexdet.nro_ref_externa := r_gextra.nro_ref_externa;
              lp_ins_ext_swift_det;
      END IF;
      --
      IF substr(msj.texto, 4, 1) = 'F' THEN
        v_sal_fin_disponible := ltrim(rtrim(substr(msj.texto, 16)));
      END IF;
      r_gextra.sal_actual  := ltrim(rtrim(substr(msj.texto, 16)));
      r_gextra.tip_saldo   := substr(msj.texto, 6, 1);
      r_gextra.fec_mensaje := to_date(substr(msj.texto, 7, 6), 'yymmdd');
      -- :64 Saldo Disponible
    ELSIF substr(msj.texto, 1, 4) = ':64:' THEN
      r_gextra.sal_disponible := ltrim(rtrim(substr(msj.texto, 15)));
      IF r_gextra.sal_disponible = 0 THEN
        r_gextra.sal_disponible := v_sal_fin_disponible;
      END IF;
    --RE DE-1015 *********************************
    ELSIF substr(msj.texto, 1, 4) = ':86:' OR  v_tag_86 = 1 THEN
      v_tag_86 := 1;
      IF r_gexdet.observacion IS NULL THEN
        r_gexdet.observacion := LTRIM(substr(msj.texto, 5));
      ELSE
        r_gexdet.observacion := r_gexdet.observacion||' '||substr(msj.texto, 1);
      END IF;
    --*********************************************
    -- BEN: Beneficiario
    ELSIF substr(msj.texto, 1, 4) = 'BEN:' THEN
       r_gexdet.descripcion := r_gexdet.descripcion||' '||LTRIM(substr(msj.texto, 1));
    ELSE
      IF r_gexdet.ref_movimiento IS NULL AND
         r_gexdet.nro_ref_externa IS NOT NULL THEN
         r_gexdet.ref_movimiento := substr(msj.texto, 1, 30);
         lp_ins_ext_swift_det;
         v_tag_86 := 0;
      END IF;
    END IF;
  END LOOP;
  RETURN v_can_reg_procesado;
EXCEPTION
  WHEN insert_detalle THEN
   raise_application_error(-20001,
                            'Error al Insertar Datos en GE_EXT_SWIFT_DET.' ||' '||
                             verror);
  WHEN insert_cabecera THEN
    raise_application_error(-20003,
                            'Error al Insertar Datos en GE_EXT_SWIFT.' ||' '||
                             verror);
    
  WHEN OTHERS THEN
    raise_application_error(-20004,
                            'Error al Insertar Extracto MT-940. Cuenta ' ||
                            r_gextra.nro_cuenta || ' HORA=' || v_hora ||
                            SQLERRM);
END;
/

