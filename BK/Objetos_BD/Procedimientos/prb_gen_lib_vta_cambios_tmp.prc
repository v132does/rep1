create or replace PROCEDURE    it.PRB_GEN_LIB_VTA_CAMBIOS_TMP (P_COD_PERSONA   IN VARCHAR2 DEFAULT NULL,
                                                        P_FECHA         IN DATE     DEFAULT NULL,
                                                        P_HORA          IN VARCHAR2 DEFAULT NULL,
                                                        P_COD_USUARIO   IN VARCHAR2 DEFAULT NULL,
                                                        P_NRO_SECUENCIA IN NUMBER   DEFAULT NULL ) IS
  v_cod_persona     varchar2(20);
  v_cod_per_ueno    ba_personas.cod_persona%type := FUG_OBT_PER_ENTIDAD;
  v_nro_doc_persona varchar2(30);
  v_nom_completo    varchar2(200);
  v_inserta         varchar2(1);
  v_tip_venta       cb_lib_ventas_det_tmp.tip_venta%type := 'CO';
  rg_lib_ventas     cb_lib_ventas_det_tmp%rowtype;
  v_cotizacion      ge_cotizaciones.val_conversion%type;
  v_cod_mon_local   ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_local;
  v_mto_gs          ge_movimientos.monto%type;
  v_tot_iva_gs      ge_movimientos.monto%type;
  v_monto_gs        number(18);
  v_tot_gra_gs      number;
  v_tot_aju_iva     number;
  v_existe          number;
  v_iva_desembolso  number := 0;
  v_tasa            number := 0;
  v_redondeo        NUMBER(2)    := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',null,null, v_cod_mon_local);
  v_nro_secuencia   ge_movimientos.nro_secuencia%type;
  v_mar_tolerancia  number(1);
  v_pre_canje       varchar2(1)    := 'N';
  v_cod_transaccion ge_movimientos.cod_transaccion%type := '760';
  v_nro_cuenta      ge_movimientos.nro_cuenta%type;
  v_lugar           varchar2(2000);
  v_fec_reg         ge_movimientos.fecha%type;
  v_hor_reg         ge_movimientos.hora%type;
  v_usu_reg         ge_movimientos.cod_usuario%type;
  v_cta_reg         varchar2(100);
  v_mensaje         varchar2(100);
  v_cod_tip_deudor  ge_clientes.cod_tip_deudor%type;

  --- Cursor Principal de movimientos con iva
  cursor principal is
        SELECT  m.fecha,
                m.hora,
                m.cod_usuario,
                m.nro_secuencia,
                m.fec_valor,
                m.cod_modulo,
                m.cod_modalidad,
                m.cod_transaccion,
                m.cod_moneda,
                decode(cod_usu_reversion, NULL, m.monto, m.monto * -1) monto,
                decode(cod_usu_reversion, NULL, decode(m.cod_moneda,'GS',nvl(m.monto,0),(nvl(m.monto,0) * nvl(m.cotizacion,0))),
                                                decode(m.cod_moneda,'GS',nvl(m.monto,0),(nvl(m.monto,0) * nvl(m.cotizacion,0))) * -1) mto_equ_local,
                m.concepto,
                m.val_tasa,
                m.cod_usu_reversion,
                m.hor_reversion,
                m.nro_cuenta,
                m.referencia,
                m.cod_mod_padre,
                m.cod_mad_padre,
                m.nro_documento2,
                decode(cod_usu_reversion, NULL, 'N', 'S') reversado,
                m.cod_oficina,
                m.cod_tra_padre,
                m.nro_documento,
                decode(m.cotizacion, 0, NULL, m.cotizacion) cotizacion,
                m.cod_persona,
                m.nro_documento3,
                m.tip_mov_rubro,
                m.cod_rubro
           FROM ge_movimientos m
          WHERE m.fecha         = nvl(P_FECHA        , m.fecha)
            AND m.hora          = nvl(P_HORA         , m.hora)
            AND m.cod_usuario   = nvl(P_COD_USUARIO  , m.cod_usuario)
            AND m.nro_secuencia = nvl(P_NRO_SECUENCIA, m.nro_secuencia)
    AND (m.cod_persona <> v_cod_per_ueno OR 
         (SELECT CASE
                   WHEN cod_persona IS NULL THEN NULL
                   ELSE cod_persona
                 END cod_cli_principal
            FROM (SELECT cod_persona
                    FROM ge_cta_clientes
                   WHERE nro_cuenta = m.nro_cuenta
                     AND relacion = 'P')
         ) <> v_cod_per_ueno)          
            AND m.monto         != 0
            AND ((EXISTS(SELECT 1
                           FROM lc_tip_operaciones b
                          WHERE b.cod_tip_operacion = m.cod_tip_ope_cambio
                            AND b.cod_mad_hijo      In (71,72)
                            AND b.afe_posicion      != 'N' ) 
                            AND m.cod_mod_padre = 7) OR (m.cod_mod_padre<>7))

            AND (NVL(M.COD_TRANSACCION, 0) NOT IN (4050, 4052, 901, 942) OR (NVL(M.COD_TRANSACCION, 0) IN (901,942) AND M.COD_PERSONA IS NOT NULL))
            AND ((m.reversado = 'N' AND m.estado NOT IN ('X', 'J', 'P')) OR (m.reversado <> 'N'))
   AND (
        -- Reemplazamos la llamada a la función 'fug_obt_pardinamico'
        (SELECT val_parametro 
         FROM ge_par_dinamicos
        WHERE nvl(cod_modulo, nvl(m.cod_mod_padre, -1)) = nvl(m.cod_mod_padre, -1)
          AND nvl(cod_modalidad, nvl(m.cod_mad_padre, -1)) = nvl(m.cod_mad_padre, -1)
          AND parametro = 'COD_MAD_IMP_FAC_EXE'
        ) = 'S'
    )            
            -- Controla que el movimiento no esté facturado.
            AND NOT EXISTS (SELECT 1
                              FROM cb_lib_ventas_det d
                             WHERE d.fecha         = m.fecha
                               AND d.hora          = m.hora
                               AND d.cod_usuario   = m.cod_usuario
                               AND d.cod_mod_padre = m.cod_mod_padre
                               AND d.cod_mad_padre = m.cod_mad_padre
                               AND d.cod_tra_padre = m.cod_tra_padre
                               AND substr(d.nro_factura,5,3) = lpad(fue_obt_val_max_refcodes('TIP_COM_VENTA','C' ),3,'00'))
            -- Controla que el movimiento no se haya procesado con el PAB_IVA.
            AND NOT EXISTS (SELECT 1
                              FROM cb_lib_ventas_det_tmp d
                             WHERE d.fecha         = m.fecha
                               AND d.hora          = m.hora
                               AND d.cod_usuario   = m.cod_usuario
                               AND d.cod_mod_padre = m.cod_mod_padre
                               AND d.cod_mad_padre = m.cod_mad_padre
                               AND d.cod_tra_padre = m.cod_tra_padre
                               and d.tip_comprobante='F')
            AND NOT EXISTS (SELECT 1
                              FROM ge_clientes c
                             WHERE c.cod_persona = m.cod_persona
                               AND c.cod_sec_contable = 'F'
                               AND INSTR(','||fug_obt_pardinamico('TIP_DEU_SEC_FINANCIERO')||',', ','||c.cod_tip_deudor||',') > 0
                               AND m.cod_mod_padre = 7
                               AND m.cod_mad_padre = 71
                             );
            

   TYPE cursor1_type IS TABLE OF principal%ROWTYPE;
   reg cursor1_type;


  --------------------------------------------------------------
  -- Función que verifica si corresponde insertar la reversión -
  --------------------------------------------------------------
  function fp_ins_reversion(p_fecha         date    ,
                            p_hora          varchar2,
                            p_cod_usuario   varchar2,
                            p_nro_secuencia varchar2) return varchar2 is
    v_existe  number := 0;
    v_inserta varchar2(1);
    begin
     -- Busca si existe entre los movimientos temporales.
     begin
       select nvl(count(*),0)
         into v_existe
         from cb_lib_ventas_det_tmp dt
        where dt.fecha         = p_fecha
          and dt.hora          = p_hora
          and dt.cod_usuario   = p_cod_usuario
          and dt.nro_secuencia = p_nro_secuencia;
     exception
       when no_data_found then
            v_existe := 0;
     end;
     if v_existe = 0 then
         -- Si no existe busca en las Facturas.
         begin
           select nvl(count(*),0)
             into v_existe
             from cb_lib_ventas_det vd
            where vd.fecha         = p_fecha
              and vd.hora          = p_hora
              and vd.cod_usuario   = p_cod_usuario
              and vd.nro_secuencia = p_nro_secuencia;
         exception
           when no_data_found then
                v_existe := 0;
         end;
         --
         if v_existe > 0 then
           v_inserta := 'S';
         else
           v_inserta := 'N';
         end if;
     else
         -- Si existe entre los temporales, borra el movimiento.
         pab_iva.pr_ins_observaciones(p_fecha, p_hora, p_cod_usuario, 'S');
         begin
             delete cb_lib_ventas_det_tmp dt
              where dt.fecha         = p_fecha
                and dt.hora          = p_hora
                and dt.cod_usuario   = p_cod_usuario
                and dt.nro_secuencia = p_nro_secuencia;
         exception
             when others then
                  raise_application_error(-20000,'Error al Elminar Registros. CB_LIB_VENTAS_DET_TMP '||sqlerrm);
         end;
         v_inserta := 'N';
     end if;
     return v_inserta;
  end fp_ins_reversion;
  --------------------------------------------------------
  -- Función para obtener la descripción de la transacción
  --------------------------------------------------------
  function f_obt_des_transaccion(p_cod_modulo      in number,
                                 p_cod_modalidad   in number,
                                 p_cod_transaccion in number) return varchar2 is
    v_descripcion ge_transacciones.descripcion%type;
  begin

      select descripcion
        into v_descripcion
        from ge_transacciones
       where cod_modulo      = p_cod_modulo
         and cod_modalidad   = p_cod_modalidad
         and cod_transaccion = p_cod_transaccion;

      return v_descripcion;
  exception
     when others then
          return null;
  end f_obt_des_transaccion;
 ----------------------------------------------------------------
  /* Función que obtiene la secuencia anterior */
 ----------------------------------------------------------------
 FUNCTION FU_OBT_SEC_ANTERIOR(p_fecha         in date    ,
                              p_hora          in varchar2,
                              p_cod_usuario   in varchar2,
                              p_nro_secuencia in number  )
 return number is
 v_nro_secuencia   ge_movimientos.nro_secuencia%type;
 begin
    select nvl(max(b.nro_secuencia), 0)
      into v_nro_secuencia
      from ge_movimientos b
     where b.fecha          = p_fecha
       and b.hora           = p_hora
       and b.cod_usuario    = p_cod_usuario
       and b.nro_secuencia  < p_nro_secuencia
       and b.cod_tra_padre  <> 309;
   return nvl(v_nro_secuencia,0);
 exception
   when no_data_found then
        return 0;
   when others then
        return p_nro_secuencia - 1;
 end;

BEGIN
    v_lugar               := 'Inicio';
    v_lugar               := 'Antes del cursor principal';
	-- Registrar el nombre en action
    DBMS_APPLICATION_INFO.SET_ACTION('PRB_GEN_LIB_VTA_CAMBIOS_TMP');
    DBMS_APPLICATION_INFO.SET_CLIENT_INFO('PRB_GEN_LIB_VTA_CAMBIOS_TMP, Iniciando');
    OPEN principal;
    LOOP
      FETCH principal BULK COLLECT INTO reg LIMIT 2500;
      FOR i IN 1 .. reg.count LOOP
          if (reg(i).cod_modulo = 7 and reg(i).cod_modalidad = 74) then
             v_pre_canje := 'S';
          else
             v_pre_canje := 'N';
          end if;

          v_existe   := 0;
          v_fec_reg  := reg(i).fecha;
          v_hor_reg  := reg(i).hora;
          v_usu_reg  := reg(i).cod_usuario;
          v_cta_reg  := reg(i).cod_modulo||'-'||reg(i).cod_modalidad||'-'||reg(i).nro_cuenta;
          v_lugar    := 'Antes de verificar reversión.';		  
		  -- Monitoreo del avance cada 100 registros o al final
          IF MOD(i, 100) = 0 OR i = reg.COUNT THEN
              v_mensaje := 'Procesando registro' || i || ' de ' || reg.COUNT;
              DBMS_APPLICATION_INFO.SET_CLIENT_INFO(v_mensaje);
          END IF;
         if nvl(reg(i).reversado,'N') = 'N' then
            --Si No está reversado Inserta.
            v_inserta := 'S';
         elsif nvl(reg(i).reversado,'N') = 'S' then
              v_inserta := fp_ins_reversion(reg(i).fec_valor,reg(i).hor_reversion,reg(i).cod_usu_reversion,reg(i).nro_secuencia);
         end if;
          if v_inserta = 'S' then
             v_lugar:= 'Rev. histórica.';
            if nvl(reg(i).cotizacion,0) = 0 then
               v_cotizacion := nvl(reg(i).cotizacion,nvl(pag_gen.fu_obt_cotizacion(reg(i).cod_moneda, reg(i).fecha),1));
            else
               v_cotizacion := reg(i).cotizacion;
            end if;
            --
            v_tot_iva_gs     := 0;
            v_tot_gra_gs     := 0;
            v_tot_aju_iva    := 0;
            v_cod_persona    := reg(i).cod_persona;
            v_lugar          := 'Obtiene datos persona.';
            pab_iva.pr_obt_dat_persona(reg(i).cod_mod_padre ,
                                       reg(i).cod_mad_padre ,
                                       reg(i).cod_usuario   ,
                                       reg(i).fecha         ,
                                       reg(i).hora          ,
                                       reg(i).nro_secuencia ,
                                       case when reg(i).cod_persona   <> v_cod_per_ueno and fug_obt_cli_principal(reg(i).nro_cuenta) = v_cod_per_ueno then
                                          null
                                       else
                                          reg(i).nro_cuenta
                                       End,
                                       reg(i).nro_documento2,
                                       reg(i).referencia    ,
                                       reg(i).cod_moneda    ,
                                       reg(i).monto         ,
                                       reg(i).val_tasa      ,
                                       v_cod_persona        ,
                                       v_nro_doc_persona    ,
                                       v_nom_completo       );

             v_mar_tolerancia := 2;

            -- Si el parametro de persona es nulo inserta todos si no por persona.
            if p_cod_persona is null or p_cod_persona = nvl(v_cod_persona,'x') then
                --Limpia el registro.
                rg_lib_ventas := null;
                if reg(i).cod_moneda = v_cod_mon_local then
                    v_monto_gs := nvl(reg(i).monto,0);
                else
                    v_monto_gs := nvl(reg(i).mto_equ_local,round(v_cotizacion * reg(i).monto));
                end if;
                -- limpiar variable
                v_iva_desembolso := 0;
                v_lugar:= 'Obtener Mov Cargo.';
                if v_cod_mon_local <> reg(i).cod_moneda then
                  v_redondeo := nvl(fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',6,NULL,reg(i).cod_moneda),0);
                else
                  v_redondeo := 0;
                end if;
                --Limpia el registro.
                rg_lib_ventas := null;

                -- Carga con ceros los montos.
                rg_lib_ventas.impuesto_10_gs  := 0;
                rg_lib_ventas.mto_gra_10_gs   := 0;
                rg_lib_ventas.mto_gravado_10  := 0;
                rg_lib_ventas.impuesto_10     := 0;
                rg_lib_ventas.impuesto_5_gs   := 0;
                rg_lib_ventas.mto_gra_5_gs    := 0;
                rg_lib_ventas.mto_gravado_5   := 0;
                rg_lib_ventas.impuesto_5      := 0;
                rg_lib_ventas.mto_exento_gs   := 0;
                rg_lib_ventas.mto_exento      := 0;
                rg_lib_ventas.aju_impuesto_10 := 0;
                rg_lib_ventas.aju_impuesto_5  := 0;
                v_mto_gs                      := NVL(reg(i).mto_equ_local,round(nvl(reg(i).monto,0)*v_cotizacion,0));
                v_tasa                        := round((reg(i).monto*100)/reg(i).monto);
                rg_lib_ventas.mto_exento_gs   := v_mto_gs;
                rg_lib_ventas.mto_exento      := nvl(reg(i).monto,0);
                rg_lib_ventas.cod_persona     := v_cod_persona;
                rg_lib_ventas.nro_doc_persona := v_nro_doc_persona;
                rg_lib_ventas.nom_completo    := v_nom_completo;
                rg_lib_ventas.cod_ofi_origen  := reg(i).cod_oficina;
                rg_lib_ventas.cod_mod_padre   := reg(i).cod_mod_padre;
                rg_lib_ventas.cod_mad_padre   := reg(i).cod_mad_padre;
                rg_lib_ventas.cod_tra_padre   := reg(i).cod_tra_padre;
                rg_lib_ventas.nro_documento   := reg(i).nro_documento;
                rg_lib_ventas.reversado       := reg(i).reversado;
                rg_lib_ventas.fecha           := reg(i).fecha;
                rg_lib_ventas.hora            := reg(i).hora;
                rg_lib_ventas.cod_usuario     := reg(i).cod_usuario;
                ---
                If reg(i).reversado = 'S' then
                    v_lugar := 'Obtener Nro Factura Rev1.';
                    begin
                      select ld.nro_factura, ld.nro_timbrado, ld.fecha
                        into rg_lib_ventas.nro_factura, rg_lib_ventas.nro_timbrado, rg_lib_ventas.fec_fac_referencia
                        from cb_lib_ventas_det ld
                       where ld.fecha         = reg(i).fec_valor
                         and ld.hora          = reg(i).hor_reversion
                         and ld.cod_usuario   = reg(i).cod_usu_reversion
                         and ld.nro_secuencia = reg(i).nro_secuencia;
                    exception
                      when no_data_found then
                           rg_lib_ventas.error := substr('No se encuentra Mov. original de Mov. Reversado en fecha = '||
                                                  to_char(reg(i).fec_valor,'dd/mm/yyyy')||
                                                  ' hora='||reg(i).hor_reversion||' usuario='||reg(i).cod_usu_reversion,1,300);
                    end;
                else
                    rg_lib_ventas.nro_factura  := 0;
                    rg_lib_ventas.nro_timbrado := 0;
                end if;
                --
                rg_lib_ventas.tip_comprobante := 'F'; --> Para identificar estas operaciones al momento de generar las facturas y obtener el número de expedición
                rg_lib_ventas.nro_secuencia   := reg(i).nro_secuencia;
                rg_lib_ventas.tip_venta       := v_tip_venta;
                rg_lib_ventas.descripcion     := substr(f_obt_des_transaccion(reg(i).cod_modulo,reg(i).cod_modalidad,reg(i).cod_transaccion),1,35);
                rg_lib_ventas.cod_moneda      := reg(i).cod_moneda;
                rg_lib_ventas.cotizacion      := v_cotizacion;
                rg_lib_ventas.cod_modulo      := reg(i).cod_modulo;
                rg_lib_ventas.cod_modalidad   := reg(i).cod_modalidad;
                rg_lib_ventas.cod_transaccion := reg(i).cod_transaccion;

                v_lugar := 'Obtener nro_cuenta pre_canje1';
                if v_pre_canje = 'S' then
                  begin
                    select a.nro_cuenta
                     into v_nro_cuenta
                      from ge_movimientos a
                     where a.fecha           = reg(i).fecha
                       and a.hora            = reg(i).hora
                       and a.cod_usuario     = reg(i).cod_usuario
                       and a.cod_transaccion = v_cod_transaccion;
                    exception
                      when others then
                        v_nro_cuenta := null;
                      end;
                   rg_lib_ventas.nro_cuenta  := v_nro_cuenta;
                else
                   rg_lib_ventas.nro_cuenta  := reg(i).nro_cuenta;
                end if;
                -- Para Hechauka 3.0 - Definir cuotas.
                v_lugar:= 'Definir Cuotas-Hechauka1';
                if reg(i).cod_transaccion = 710 then
                   rg_lib_ventas.can_cuota := 1;
                else
                   rg_lib_ventas.can_cuota := 0;
                end if;
                --
                begin
                  v_lugar:= 'Inserta Libro Vta tmp1';
                  pab_iva.pr_ins_lib_ven_tmp(rg_lib_ventas);
                exception
                  when dup_val_on_index then
                       v_tot_iva_gs    := v_monto_gs;
                       v_tot_gra_gs    := 0;
                       rg_lib_ventas   := null;
                  when others then
                       it_mail.mail(fug_obt_dir_correo,
                                    fug_obt_pardinamico('IVA_ENV_COR_ERRORES'),
                                    'Error al insertar datos en Libro Venta Temporal.',
                                    'Se ha encontrado un error al intentar insertar datos en el Libro Venta Temporal. A continuación los datos de la mensajería: ' ||
                                    chr(10) || 'Nro. Factura : '               ||
                                    rg_lib_ventas.nro_factura                  || chr(10) ||
                                    'Nro. Cuenta: '                            ||
                                    reg(i).nro_cuenta                          || chr(10) ||
                                    'Fecha: '                                  ||
                                    to_char(rg_lib_ventas.fecha, 'DD/MM/YYYY') || chr(10) ||
                                    'Hora: '                                   ||
                                    rg_lib_ventas.hora                         || chr(10) ||
                                    'Monto: '                                  ||
                                    TRIM(to_char(reg(i).monto, '999,999,999,999,999.99')) ||
                                    chr(10) || chr(10) || 'Atentamente.');
                       raise_application_error(-20000,'Error al insertar datos en Libro Venta Temporal '||sqlerrm);
                  end;
            end if;
          end if;
      end loop;
      EXIT WHEN principal%NOTFOUND;
    END LOOP;
    close principal;
	-- Dejar null la acción para que no quede en memoria 
     DBMS_APPLICATION_INFO.SET_ACTION(NULL);
     DBMS_APPLICATION_INFO.SET_CLIENT_INFO(NULL);
EXCEPTION

  WHEN OTHERS THEN
  -- Dejar null la acción para que no quede en memoria 
     DBMS_APPLICATION_INFO.SET_ACTION(NULL);
     DBMS_APPLICATION_INFO.SET_CLIENT_INFO(NULL); 
    raise_application_error(-20001,'Error al Generar el Libro de venta Tmp. en el Mov: '||
                                   'Fec: '||to_char(v_fec_reg,'DD/MM/YYYY')||', Hora: '||v_hor_reg||
                                   ', Usu: '||v_usu_reg||', Cta: '||v_cta_reg||'. En el lugar: '||v_lugar||'.'||sqlerrm);
END;
