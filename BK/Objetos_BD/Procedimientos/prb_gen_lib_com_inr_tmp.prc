CREATE OR REPLACE PROCEDURE IT.PRB_GEN_LIB_COM_INR_TMP  (P_FECHA         IN DATE     DEFAULT NULL,
                                                      p_cod_persona   in ge_inr_retenciones.cod_persona%type default null,
                                                      p_nro_cuenta    in ge_inr_retenciones.nro_cuenta%type default null) IS
  -- Proposito: Generar facturas temporales de Compra de Divisas por Operacion de Cambios --
  v_cod_persona     varchar2(20);
  v_cod_per_entidad ba_personas.cod_persona%type := FUG_OBT_PER_ENTIDAD;
  v_nro_doc_persona varchar2(30);
  v_nom_completo    varchar2(200);
  v_inserta         varchar2(1);
  v_tip_compra      cb_lib_compras_det_tmp.tip_compra%type := 'CO';
  rg_lib_compras    cb_lib_compras_det_tmp%rowtype;
  v_cotizacion      ge_cotizaciones.val_conversion%type;
  v_cod_mon_local   ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_local;
  v_mto_gs          gv_movimientos.monto%type;
  v_tot_iva_gs      gv_movimientos.monto%type;
  v_monto_gs        number(18);
  v_tot_gra_gs      number;
  v_tot_aju_iva     number;
  v_existe          number;
  v_iva_desembolso  number := 0;
  v_tasa            number := 0;
  v_redondeo        NUMBER(2)    := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',null,null, v_cod_mon_local);
  v_nro_secuencia   gv_movimientos.nro_secuencia%type;
  v_mar_tolerancia  number(1);
  v_pre_canje       varchar2(1)    := 'N';
  v_cod_transaccion gv_movimientos.cod_transaccion%type := '760';
  v_nro_cuenta      gv_movimientos.nro_cuenta%type;
  v_lugar           varchar2(2000);
  v_fec_reg         gv_movimientos.fecha%type;
  v_hor_reg         gv_movimientos.hora%type;
  v_usu_reg         gv_movimientos.cod_usuario%type;
  v_cta_reg         varchar2(100);
  rg_actret         ge_inr_retenciones%rowtype;
  
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
                r.nro_cuenta,
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
                m.cod_rubro,
                r.fec_retencion,
                r.nro_cupon
           FROM ge_inr_retenciones r, 
                ge_movimientos m
          WHERE r.fec_retencion         = nvl(P_FECHA        , m.fecha)
            and (r.nro_cta_credito = m.nro_cuenta
                 or 
                 r.nro_cuenta = m.nro_cuenta)
          and r.hora = m.hora
          and r.cod_usuario = m.cod_usuario
          and r.nro_secuencia = m.nro_secuencia
          and ((m.cod_modalidad = 33 and r.nro_cupon = m.nro_documento)
               or m.cod_modalidad = 31)
          and r.cod_persona = nvl(p_cod_persona, r.cod_persona)
          and r.nro_cuenta = nvl(p_nro_cuenta, r.nro_cuenta)
          and ( m.cod_persona   <> v_cod_per_entidad 
              or fug_obt_cli_principal(m.nro_cuenta) <> v_cod_per_entidad)
          AND m.monto         > 0
          -- Controla que el movimiento no esté facturado.
          AND NOT EXISTS (SELECT 1
                           FROM cb_lib_compras_det d
                          WHERE d.fecha         = m.fecha
                            AND d.hora          = m.hora
                            AND d.cod_usuario   = m.cod_usuario
                            AND d.cod_mod_padre = m.cod_mod_padre
                            AND d.cod_mad_padre = m.cod_mad_padre
                            AND d.cod_tra_padre = m.cod_tra_padre
                            AND substr(d.nro_factura,5,3) = lpad(fue_obt_val_max_refcodes('TIP_COM_VENTA','I' ),3,'0'))
           -- Controla que el movimiento no se haya procesado con el PAB_IVA.
           AND NOT EXISTS (SELECT 1
                             FROM cb_lib_compras_det_tmp d
                            WHERE d.fecha           = m.fecha
                              AND d.hora            = m.hora
                              AND d.cod_usuario     = m.cod_usuario
                              AND d.cod_mod_padre   = m.cod_mod_padre
                              AND d.cod_mad_padre   = m.cod_mad_padre
                              AND d.cod_tra_padre   = m.cod_tra_padre
                              AND d.tip_comprobante = 'I');



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
         from cb_lib_compras_det_tmp dt
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
             from cb_lib_compras_det vd
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
         --pab_iva.pr_ins_observaciones(p_fecha, p_hora, p_cod_usuario, 'S');
         begin
             delete cb_lib_compras_det_tmp dt
              where dt.fecha         = p_fecha
                and dt.hora          = p_hora
                and dt.cod_usuario   = p_cod_usuario
                and dt.nro_secuencia = p_nro_secuencia;
         exception
             when others then
                  raise_application_error(-20000,'Error al Elminar Registros. cb_lib_compras_det_tmp '||sqlerrm);
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

BEGIN
    v_lugar               := 'Inicio';
    v_lugar               := 'Antes del cursor principal';
    OPEN principal;
    LOOP
      FETCH principal BULK COLLECT INTO reg LIMIT 2500;
      FOR i IN 1 .. reg.count LOOP
          v_pre_canje := 'N';
          v_existe   := 0;
          v_fec_reg  := reg(i).fecha;
          v_hor_reg  := reg(i).hora;
          v_usu_reg  := reg(i).cod_usuario;
          v_cta_reg  := reg(i).cod_modulo||'-'||reg(i).cod_modalidad||'-'||reg(i).nro_cuenta;
          v_lugar    := 'Antes de verificar reversión.';

         if nvl(reg(i).reversado,'N') = 'N' then
            --Si No está reversado Inserta.
            v_inserta := 'S';
         elsif nvl(reg(i).reversado,'N') = 'S' then
         --- Verificar que se hace si el movimiento esta reversado y ya se genero la factura??---
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
                                       case when reg(i).cod_persona   <> v_cod_per_entidad and fug_obt_cli_principal(reg(i).nro_cuenta) = v_cod_per_entidad then
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
                --Limpia el registro.
                rg_lib_compras := null;
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
                rg_lib_compras := null;

                -- Carga con ceros los montos.
                rg_lib_compras.impuesto_10_gs  := 0;
                rg_lib_compras.mto_gra_10_gs   := 0;
                rg_lib_compras.mto_gravado_10  := 0;
                rg_lib_compras.impuesto_10     := 0;
                rg_lib_compras.impuesto_5_gs   := 0;
                rg_lib_compras.mto_gra_5_gs    := 0;
                rg_lib_compras.mto_gravado_5   := 0;
                rg_lib_compras.impuesto_5      := 0;
                rg_lib_compras.mto_exento_gs   := 0;
                rg_lib_compras.mto_exento      := 0;
                rg_lib_compras.aju_impuesto_10 := 0;
                rg_lib_compras.aju_impuesto_5  := 0;
                v_mto_gs                      := round(nvl(reg(i).monto,0)*v_cotizacion,0);
                v_tasa                        := round((reg(i).monto*100)/reg(i).monto);
                rg_lib_compras.mto_exento_gs   := v_mto_gs;
                rg_lib_compras.mto_exento      := nvl(reg(i).monto,0);
                rg_lib_compras.cod_persona     := v_cod_persona;
                rg_lib_compras.nro_doc_persona := v_nro_doc_persona;
                rg_lib_compras.nom_completo    := v_nom_completo;
                rg_lib_compras.cod_ofi_origen  := reg(i).cod_oficina;
                rg_lib_compras.cod_mod_padre   := reg(i).cod_mod_padre;
                rg_lib_compras.cod_mad_padre   := reg(i).cod_mad_padre;
                rg_lib_compras.cod_tra_padre   := reg(i).cod_tra_padre;
                rg_lib_compras.nro_documento   := reg(i).nro_documento;
                rg_lib_compras.reversado       := reg(i).reversado;
                rg_lib_compras.fecha           := reg(i).fecha;
                rg_lib_compras.hora            := reg(i).hora;
                rg_lib_compras.cod_usuario     := reg(i).cod_usuario;
             
                rg_lib_compras.tip_comprobante := 'I'; --> Para identificar estas operaciones al momento de generar las facturas de cambios y obtener el número de expedición
                rg_lib_compras.nro_secuencia   := reg(i).nro_secuencia;
                rg_lib_compras.tip_compra      := v_tip_compra;
                rg_lib_compras.descripcion     := 'Pago de intereses';
                rg_lib_compras.cod_moneda      := reg(i).cod_moneda;
                rg_lib_compras.cotizacion      := v_cotizacion;
                rg_lib_compras.cod_modulo      := reg(i).cod_modulo;
                rg_lib_compras.cod_modalidad   := reg(i).cod_modalidad;
                rg_lib_compras.cod_transaccion := reg(i).cod_transaccion;
                rg_lib_compras.nro_cuenta  := reg(i).nro_cuenta;
                rg_lib_compras.referencia := reg(i).nro_cupon;
                
                -- Para Hechauka 3.0 - Definir cuotas.
                v_lugar:= 'Definir Cuotas-Hechauka1';
                rg_lib_compras.can_cuota := 0;
                --
                begin
                  v_lugar:= 'Inserta Libro Compra tmp';
                  pab_iva.pr_ins_lib_com_tmp(rg_lib_compras);
                exception
                  when dup_val_on_index then
                       v_tot_iva_gs    := v_monto_gs;
                       v_tot_gra_gs    := 0;
                       rg_lib_compras   := null;
                  when others then

                  ---Actualización por Error - Para notificar
                  rg_actret.det_error := 'Error al insertar datos en Libro Compra Temporal';
                  rg_actret.pro_error := 'PRB_GEN_LIB_COM_INR_TMP';
                  rg_actret.cod_persona := v_cod_persona;
                  rg_actret.fec_retencion := reg(i).fec_retencion;
                  rg_actret.nro_cuenta := v_nro_cuenta;
                  paa_ret.pr_act_ge_inr_retenciones(rg_actret);
                end;
          end if;
       
       end loop;
      EXIT WHEN principal%NOTFOUND;
    END LOOP;
EXCEPTION

  WHEN OTHERS THEN
    raise_application_error(-20001,'Error al Generar el Libro de Compra Tmp. en el Mov: '||
                                   'Fec: '||to_char(v_fec_reg,'DD/MM/YYYY')||', Hora: '||v_hor_reg||
                                   ', Usu: '||v_usu_reg||', Cta: '||v_cta_reg||'. En el lugar: '||v_lugar||'.'||sqlerrm);
END;
/

