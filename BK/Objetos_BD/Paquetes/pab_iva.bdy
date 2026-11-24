CREATE OR REPLACE PACKAGE BODY IT.PAB_IVA IS
 v_nro_fac_retorno  cb_lib_ventas.nro_factura%type; -- para el retorno de la funcion
 v_ofi_pto_generico ba_oficinas.cod_oficina%TYPE := NVL(fug_obt_pardinamico('CON_OFI_PTO_EXP_GENERICO'),'-1');

FUNCTION LF_OBT_COD_RUBRO
  (p_cod_modulo IN NUMBER,
   p_cod_modalidad IN NUMBER,
   p_cod_transaccion IN NUMBER,
   p_cod_moneda IN VARCHAR2,
   p_cod_sec_contable IN VARCHAR2,
   p_cod_tip_deudor IN NUMBER,
   p_residente IN VARCHAR2,
   p_cod_plazo IN VARCHAR2,
   p_tip_movimiento IN VARCHAR2,
   p_cod_sit_contable in number default null,
   p_est_cuenta in varchar2 default null,
   p_tip_renovacion in varchar2 default null,
   p_cat_automatica in number default null,
   p_tip_interes    in varchar2 default null,
   p_tip_cuenta     in varchar2 default null)
 RETURN varchar2   IS
v_cod_tip_asiento number(6);
v_cod_tip_asiento2 number(6);
v_ind_deudor varchar2(1);
v_ind_plazo varchar2(1);
v_ind_producto varchar2(1);
v_cod_pro_contable number(3);
p_cod_rubro  VARCHAR2(20);

BEGIN
   /* busco la transaccion que le corresponde */
   SELECT tr.cod_tip_asiento, cod_tip_asiento2, cod_pro_contable
     INTO v_cod_tip_asiento,  v_cod_tip_asiento2, v_cod_pro_contable
     FROM ge_modalidades mo, ge_transacciones tr
    WHERE tr.cod_modulo = p_cod_modulo
      AND tr.cod_modalidad = p_cod_modalidad
      AND tr.cod_transaccion = p_cod_transaccion
      and mo.cod_modulo = p_cod_modulo
      and mo.cod_modalidad = p_cod_modalidad;
   /* busco la cuenta contable que le corresponde */
   SELECT ind_plazo, ind_deudor, cod_rubro, ind_producto
     INTO v_ind_plazo,v_ind_deudor, p_cod_rubro, v_ind_producto
     FROM ge_tip_asientos
    WHERE cod_tip_asiento in (v_cod_tip_asiento, v_cod_tip_asiento2)
      AND cod_moneda = p_cod_moneda
      AND (cod_sec_contable is null or cod_sec_contable = p_cod_sec_contable)
      and (tip_renovacion is null or tip_renovacion = NVL(p_tip_renovacion,'A'))
      and (tip_interes is null or tip_interes = p_tip_interes)
      and (tip_cuenta is null or tip_cuenta = p_tip_cuenta)
      and (cat_automatica is null or cat_automatica = p_cat_automatica)
      and (est_cuenta is null or est_cuenta = p_est_cuenta)
      AND (ind_residente = 'X' OR ind_residente = p_residente)
      and (cod_sit_contable is null or cod_sit_contable = p_cod_sit_contable)
      AND tip_movimiento = p_tip_movimiento
      AND nro_linea =  ( Select min(nro_linea)
                           FROM ge_tip_asientos
                          WHERE cod_tip_asiento = v_cod_tip_asiento
                            AND cod_moneda = p_cod_moneda
                            AND (cod_sec_contable is null or cod_sec_contable = p_cod_sec_contable)
                            and (tip_renovacion is null or tip_renovacion = NVL(p_tip_renovacion,'A'))
                            and (tip_interes is null or tip_interes = p_tip_interes)
                            and (tip_cuenta is null or tip_cuenta = p_tip_cuenta)
                            and (cat_automatica is null or cat_automatica = p_cat_automatica)
                            and (est_cuenta is null or est_cuenta = p_est_cuenta)
                            AND (ind_residente = 'X' OR ind_residente = p_residente)
                            and (cod_sit_contable is null or cod_sit_contable = p_cod_sit_contable)
                            AND tip_movimiento = p_tip_movimiento)
      AND ROWNUM = 1;
   IF v_ind_plazo = 'S' then
      p_cod_rubro := substr(p_cod_rubro,1,2)||p_cod_plazo||
                    substr(p_cod_rubro,4,12);
   END IF;
   IF v_ind_deudor = 'S' OR substr(p_cod_rubro,9,2) = 'TD' then
      p_cod_rubro := substr(p_cod_rubro,1,8)||
                    (ltrim(to_char(p_cod_tip_deudor,'00')))||
                    substr(p_cod_rubro,11,5);
   END IF;
   ---Reemplaza el codigo del producto -----------------------
   IF v_IND_PRODUCTO = 'S' THEN
      p_cod_rubro := SUBSTR(p_cod_rubro,1,10)||
                     LTRIM(TO_CHAR(v_cod_pro_contable,'000'))||
                     SUBSTR(p_cod_rubro,14,2);
   END IF;
   return p_cod_rubro;
EXCEPTION
   WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20000,' '||SQLERRM);
        p_cod_rubro := NULL;
        return p_cod_rubro;
END;

-- retorna el punto de expedicion para el tipo de comprobante
FUNCTION FU_OBT_PUN_EXPEDICION
  (   p_tip_comprobante IN VARCHAR2,
      p_cod_oficina     IN ba_oficinas.cod_oficina%TYPE DEFAULT NULL,
      p_cod_modulo      IN ba_modulos.cod_modulo%TYPE DEFAULT NULL,
      p_cod_modalidad   IN ge_modalidades.cod_modalidad%TYPE DEFAULT NULL  -- DA-8395
   ) RETURN NUMBER IS
  v_pun_expedicion number(3);
BEGIN
  --Oficina Generica
  IF v_ofi_pto_generico <> -1 THEN
     BEGIN
        SELECT to_number(val_maximo)
          INTO v_pun_expedicion
          FROM ba_cod_referencias
         WHERE dominio = 'TIP_COM_VENTA'
           AND val_minimo = p_tip_comprobante;
     EXCEPTION
        WHEN OTHERS THEN
           raise_application_error(-20000,
                                   'Falta definir el punto de expedicion para el tipo de comprobante ' ||
                                    p_tip_comprobante || ' en oficina: ' || p_cod_oficina);
     END;
  ELSE
    IF p_tip_comprobante = 'F' THEN
      IF p_cod_modulo = 5 then -- DA-8395
        v_pun_expedicion := fug_obt_pardinamico('PTO_EXP_FACTURA', p_cod_modulo, p_cod_modalidad, NULL,p_cod_oficina);
      ELSE
        v_pun_expedicion := fug_obt_pardinamico('PTO_EXP_FACTURA', p_cod_modulo, NULL, NULL,p_cod_oficina);
      END IF;
    ELSIF p_tip_comprobante = 'N' THEN
      v_pun_expedicion := fug_obt_pardinamico('PTO_EXP_NOTA', NULL, NULL, NULL, p_cod_oficina);
    ELSIF p_tip_comprobante = 'T' THEN
      v_pun_expedicion := fug_obt_pardinamico('PTO_EXP_AUTOFACTURA', NULL, NULL, NULL,p_cod_oficina);
    END IF;                                                  
 END IF;
 
 IF v_pun_expedicion IS NULL THEN
   raise_application_error(-20000,
                           'Falta definir el punto de expedicion para el tipo de comprobante ' ||
                            p_tip_comprobante || ' en oficina: ' || p_cod_oficina);
 END IF;
RETURN v_pun_expedicion;
exception
  when others then
    raise_application_error(-20000, 'Problema al obtener punto de expedicion del comprobante. ' || sqlerrm);
end;
---------------------------------------------------------------------
-- Función para determinar si la transaccion afecta saldo de tarjeta
---------------------------------------------------------------------
function FU_OBT_AFECTA (p_cod_modulo in number,
                       p_cod_modalidad in number,
                       p_cod_transaccion in number
                       ) return varchar2 is
     v_afecta varchar2(1);
  begin
     Select afecta into v_afecta
       from ge_transacciones
        where cod_modulo = p_cod_modulo
          and cod_modalidad = p_cod_modalidad
          and cod_transaccion = p_cod_transaccion;
     return v_afecta;
  exception
     When OTHERS then
          v_afecta := null;
          return v_afecta;
end fu_obt_afecta;

/* Genera libro venta de las reversiones. */
PROCEDURE PR_GEN_NOT_CREDITO
 (P_COD_PERSONA IN VARCHAR2 := null
 ,P_FECHA IN DATE := null
 ,P_HORA IN VARCHAR2 := null
 ,P_COD_USUARIO IN VARCHAR2 := null
 )
 IS
--- Variables de corte de control
   v_cod_persona  cb_lib_ventas.cod_persona%type;      --AP 1458 Para realizar corte también por persona
   v_nro_cuenta  cb_lib_ventas_det.nro_cuenta%type;    -- FIELDESK-165438 Para realizar corte por nro de cuenta 
   v_nro_tim_ncr  cb_lib_ventas.nro_timbrado%type;
   v_nro_fac_ant  cb_lib_ventas.nro_factura%type;
   v_nro_tim_ant  cb_lib_ventas.nro_timbrado%type;
   v_nro_ncredito cb_lib_ventas.nro_factura%type;
   v_fec_vig_tim  date;
   rv_blven       cb_lib_ventas%rowtype;
   rv_blvde       cb_lib_ventas_det%rowtype;
   v_fec_proceso  date;
   v_fec_aut_timbrado cb_par_comprobantes.fec_autorizacion%type;
   v_nro_lin_fac  number(4);  -- Nro. de Lineas que puede tener una factura
   v_nro_linea    number(4);  -- Cantidad de lineas impresas de la factura
   v_cod_oficina  number(4);
   v_cod_mon_factura varchar2(5);
   v_tip_imp      ge_par_generales.tip_implementacion%type;
   v_pun_expedicion number(3); -- Punto de Expedicion del comprobante
   v_borrado         NUMBER := 0; --bandera para borrar cabecera cb_lib_ventas_tmp
   v_mensaje         varchar2(100);
   --- Cursor de movimientos reversados de la persona por factura
   cursor c_reversados is
   select v.cod_persona, v.fecha, v.hora, v.cod_usuario, v.nro_secuencia, v.cod_ofi_origen,
          v.tip_comprobante, v.tip_venta,
          v.cod_mod_padre, v.cod_mad_padre, v.cod_tra_padre,
          v.descripcion,
          v.cod_moneda, v.mto_exento, v.mto_exento_gs, v.mto_gravado_5, v.mto_gra_5_gs,
          v.mto_gravado_10, v.mto_gra_10_gs, v.impuesto_5, v.impuesto_5_gs,
          v.impuesto_10, v.impuesto_10_gs, v.cotizacion, nvl(c.cod_oficina,v.cod_ofi_origen) cod_oficina, v.nom_completo,
          v.nro_doc_persona nro_documento, p.tipo, v.nro_cuenta,
          v.nro_documento nro_recibo, v.nro_factura, v.nro_timbrado,
          v.rowid fila, v.aju_impuesto_5, v.aju_impuesto_10,
          decode(nvl(fue_per_dat_adicional(nvl(p_cod_persona,v.cod_persona),'TIP_FACTURACION'),'L'),'L','GS',v.cod_moneda) cod_mon_factura
      ,v.cod_transaccion,v.cod_modulo,v.cod_modalidad,p.tip_iva, /*DYDMR-5605 NAF 03/2017*/
      v.fec_fac_referencia
   from cb_lib_ventas_det_tmp v, ge_clientes c, ba_personas p
    where nvl(v.reversado,'N') = 'S'
      and c.cod_persona(+) =  v.cod_persona
      and p.cod_persona(+)  = v.cod_persona
      --- Verificar si tiene parámetros
      and ((v.cod_persona  = nvl(p_cod_persona,v.cod_persona)) or
           (v.cod_persona is null and p_cod_persona is null))
      and v.fecha        = nvl(p_fecha,v.fecha)
      and v.hora         = nvl(p_hora,v.hora)
      and v.error is null  -- solo tomas los que no tienen error
      and v.cod_usuario  = nvl(p_cod_usuario,v.cod_usuario)
   order by v.cod_persona, v.nro_cuenta, v.nro_timbrado, v.nro_factura;  --AP 1458 Para realizar corte también por persona

   TYPE cursor1_type IS TABLE OF c_reversados%ROWTYPE;
   reg cursor1_type;

BEGIN
   v_cod_persona := '-1';  --AP 1458 para corte de control también por cod_persona
   v_nro_cuenta  := '-1';  --FIELDESK-165438 para corte de control por nro_cuenta
   v_nro_fac_ant := '-1';
   v_nro_tim_ant := '-1';
   v_nro_lin_fac := 45;   -- esta es la cantidad de líneas por factura que se puede imprimir
   v_nro_linea   := 0;
   v_cod_mon_factura := '.';
   --v_fec_proceso := pag_cal.fu_obt_fec_actual(1);
   v_tip_imp     := fug_obt_tip_implementacion;
   -- Registrar el nombre en action
   DBMS_APPLICATION_INFO.SET_ACTION('PAB_IVA');
   DBMS_APPLICATION_INFO.SET_CLIENT_INFO('PR_GEN_NOT_CREDITO, iniciando');
OPEN c_reversados;
   LOOP
      FETCH c_reversados BULK COLLECT
         INTO reg LIMIT 2500;
      FOR i IN 1 .. reg.count LOOP
        --FOR reg IN c_reversados LOOP * Se comenta, pues ahora se utilizará el método Bulk Collect * RM --
        -- Monitoreo del avance cada 100 registros 
        IF MOD(i, 100) = 0 OR i = reg.COUNT THEN
            v_mensaje := 'PR_GEN_NOT_CREDITO-registro ' || i || ' de ' || reg.COUNT;
            DBMS_APPLICATION_INFO.SET_CLIENT_INFO(v_mensaje);
        END IF;    
        v_fec_proceso := reg(i).fecha;
      --- Corte de control
      if nvl(v_cod_persona,'-2') <> nvl(reg(i).cod_persona,'-2')
        or nvl(v_nro_cuenta,'-2') <> nvl(reg(i).nro_cuenta,'-2')
        or nvl(v_nro_fac_ant,'-2') <> nvl(reg(i).nro_factura,'-2') or nvl(v_nro_tim_ant,'-2') <> nvl(reg(i).nro_timbrado,'-2')
        or nvl(v_cod_mon_factura,'.') <> nvl(reg(i).cod_mon_factura,'.')
        or v_nro_linea + 1 > v_nro_lin_fac then
           v_cod_oficina := reg(i).cod_oficina; --- Modificado por ICL 05/03/2010 para que ponga oficina del cliente
           --Si existe Oficina Generica
           IF v_ofi_pto_generico <> -1 THEN
             v_cod_oficina := v_ofi_pto_generico;
           END IF;
           v_pun_expedicion := fu_obt_pun_expedicion('N',v_cod_oficina);
           --- Insertar cabecera para la Nota de Crédito por factura
           pab_iva.pr_obt_nro_factura(v_cod_oficina, v_fec_proceso, 'N', v_nro_ncredito, v_nro_tim_ncr, v_fec_vig_tim);--Modificado ICL 12/03/2010 xq la numeracion es unica para todas las oficinas
           begin
             select fec_ini_timbrado
               into v_fec_aut_timbrado
               from cb_par_comprobantes a
              where nro_timbrado = v_nro_tim_ncr
                and tipo = 'N'
                and cod_oficina = v_cod_oficina;
           exception
             when no_data_found then
               raise_application_error(-20000,'No se ha encontrado fecha de inicio de timbrado
                                               para la ofic. '||v_cod_oficina||' Tip. compr. NC.' ||sqlerrm);
             when others then
               raise_application_error(-20000,'Error en PAB_IVA.PRG_GEN_NOT_CREDITO'||sqlerrm);
           end;
          --- Insertar cabecera
           rv_blven.nro_factura        := lpad(fug_obt_pardinamico('COD_OFI_HACIENDA', null, null, null, v_cod_oficina),3,'0')||
                                            '-'||lpad(v_pun_expedicion,3,'0')||
                                            '-'||lpad(to_char(v_nro_ncredito),7,'0');
           v_nro_fac_retorno           := rv_blven.nro_factura; --BBVASOP-1209
           rv_blven.nro_timbrado       := v_nro_tim_ncr;
           rv_blven.fec_vig_timbrado   := v_fec_vig_tim;
           rv_blven.nro_fac_referencia := reg(i).nro_factura;
           rv_blven.nro_tim_referencia := reg(i).nro_timbrado;
           rv_blven.fec_aut_timbrado   := v_fec_aut_timbrado;
           rv_blven.fecha              := v_fec_proceso;
           rv_blven.cod_oficina        := v_cod_oficina;
           rv_blven.tip_comprobante    := 'N';
           rv_blven.tip_venta          := reg(i).tip_venta;
           if reg(i).cod_persona is not null then
             rv_blven.cod_persona        := reg(i).cod_persona;
             rv_blven.nom_completo       := reg(i).nom_completo;
             rv_blven.nro_documento      := reg(i).nro_documento;
             rv_blven.dig_verificador    := null;
             if reg(i).tipo = 'J' then
               begin
                 if instr(reg(i).nro_documento,'-') > 0 then
                   rv_blven.nro_documento   := substr(reg(i).nro_documento,1,instr(reg(i).nro_documento,'-')-1);
                   rv_blven.dig_verificador := substr(reg(i).nro_documento,-1);
                 end if;
               exception
                  when others then
                     rv_blven.nro_documento := reg(i).nro_documento;
                     rv_blven.dig_verificador := NULL;
               end;
             else
               begin
                 if instr(reg(i).nro_documento,'-') > 0 then
                    rv_blven.nro_documento   := substr(reg(i).nro_documento,1,instr(reg(i).nro_documento,'-')-1);
                    rv_blven.dig_verificador := substr(reg(i).nro_documento,-1);
                 else
                   -- DYDMR-5605 NAF 03/2017 Si el cliente es no contribuyente dig_verificador es NULL
                    if reg(i).tip_iva = 'NC' then
                      rv_blven.dig_verificador := NULL;
                    else
                      rv_blven.dig_verificador := fue_obt_ruc_dig_verificador(reg(i).nro_documento);
                    end if;
                 end if;
               exception
                  when others then
                     rv_blven.nro_documento := reg(i).nro_documento;
                     rv_blven.dig_verificador := NULL;
               end;
             end if;
             rv_blven.direccion          := fue_obt_dir_principa(reg(i).cod_persona);
             rv_blven.telefono           := fue_obt_tel_principa(reg(i).cod_persona);
           else
             rv_blven.cod_persona        := null;
             rv_blven.nom_completo       := 'SIN NOMBRE';
             rv_blven.nro_documento      := 'X';
             rv_blven.dig_verificador    := null;
             rv_blven.direccion          := null;
             rv_blven.telefono           := null;
           end if;
           rv_blven.cod_moneda         := reg(i).cod_mon_factura;
           rv_blven.fec_fac_referencia := reg(i).fec_fac_referencia;
           rv_blven.serie              := IT.FUG_OBT_SERIE(nvl(reg(i).tip_comprobante, 'F'),
                                                           v_cod_oficina,
                                                           v_nro_tim_ncr);
           pab_iva.PR_INS_LIB_VEN_CAB(rv_blven);
           --- Obs. Los totales de la cabecera son por trigger
           v_cod_persona := reg(i).cod_persona;    --AP 1458 23/02/2012
           v_nro_cuenta  := reg(i).nro_cuenta;    --FIELDESK-165438 19/10/2026
           v_nro_fac_ant := reg(i).nro_factura;
           v_nro_tim_ant := reg(i).nro_timbrado;
           v_nro_linea   := 0;
           v_cod_mon_factura := reg(i).cod_mon_factura;
      end if;
      v_nro_linea             := v_nro_linea + 1;
      --- Insertar detalles
      rv_blvde.fecha          := reg(i).fecha;
      rv_blvde.hora           := reg(i).hora;
      rv_blvde.cod_usuario    := reg(i).cod_usuario;
      rv_blvde.nro_secuencia  := reg(i).nro_secuencia;
      rv_blvde.nro_factura    := rv_blven.nro_factura;
      rv_blvde.nro_timbrado   := rv_blven.nro_timbrado;
      rv_blvde.cod_ofi_origen := reg(i).cod_ofi_origen;
      rv_blvde.cod_mod_padre  := reg(i).cod_mod_padre;
      rv_blvde.cod_mad_padre  := reg(i).cod_mad_padre;
      rv_blvde.cod_tra_padre  := reg(i).cod_tra_padre;
      rv_blvde.nro_documento  := reg(i).nro_recibo;
      rv_blvde.descripcion    := reg(i).descripcion;
      rv_blvde.cod_moneda     := reg(i).cod_moneda;
      rv_blvde.mto_exento     := reg(i).mto_exento;
      rv_blvde.mto_exento_gs  := reg(i).mto_exento_gs;
      rv_blvde.mto_gravado_5  := reg(i).mto_gravado_5;
      rv_blvde.mto_gra_5_gs   := reg(i).mto_gra_5_gs;
      rv_blvde.mto_gravado_10 := reg(i).mto_gravado_10;
      rv_blvde.mto_gra_10_gs  := reg(i).mto_gra_10_gs;
      rv_blvde.impuesto_5     := reg(i).impuesto_5;
      rv_blvde.impuesto_5_gs  := reg(i).impuesto_5_gs;
      rv_blvde.impuesto_10    := reg(i).impuesto_10;
      rv_blvde.impuesto_10_gs := reg(i).impuesto_10_gs;
      rv_blvde.cotizacion     := reg(i).cotizacion;
      rv_blvde.nro_cuenta     := reg(i).nro_cuenta;
      rv_blvde.aju_impuesto_5 := reg(i).aju_impuesto_5;
      rv_blvde.aju_impuesto_10:= reg(i).aju_impuesto_10;
      --Transac. Mod. Moda.
      rv_blvde.cod_modulo:= reg(i).cod_modulo;
      rv_blvde.cod_modalidad:= reg(i).cod_modalidad;
      rv_blvde.cod_transaccion:= reg(i).cod_transaccion;
      rv_blvde.tip_comprobante := 'N';
    pab_iva.PR_INS_LIB_VEN_DET(rv_blvde);
      -- borro el registro procesado
    delete cb_lib_ventas_det_tmp
      where rowid = reg(i).fila;
    v_borrado := 1;
   end loop;
   EXIT WHEN c_reversados%NOTFOUND;
END LOOP;
   close c_reversados;
   IF v_borrado <> 0 THEN
         DELETE cb_lib_ventas_tmp
          WHERE cod_persona = p_cod_persona
        AND reversado = 'S'
            AND (fecha = p_fecha OR p_fecha is null)
            AND (hora = p_hora or p_hora is null)
            AND (cod_usuario = p_cod_usuario or p_cod_usuario is null);
   END IF;
    -- Dejar null para que no quede en memoria 
    DBMS_APPLICATION_INFO.SET_ACTION(NULL);
    DBMS_APPLICATION_INFO.SET_CLIENT_INFO(NULL); 
END;
/* Insertar el libro de venta cabecera. */
PROCEDURE PR_INS_LIB_VEN_CAB
 (RP_BLVEN IN CB_LIB_VENTAS%ROWTYPE
 )
 IS
 v_fec_ini_timbrado   cb_lib_ventas.fec_ini_timbrado%type;
 v_nro_aut_timbrado   cb_lib_ventas.nro_aut_timbrado%type;
BEGIN
  --CANREQVAR-326 - HO - Se agrega la insercion de los 2 nuevos campos de cb_lib_ventas
  begin
   select fec_ini_timbrado, nro_aut_timbrado
     into v_fec_ini_timbrado, v_nro_aut_timbrado
     from cb_par_comprobantes
    where nro_timbrado = rp_blven.nro_timbrado
      and tipo = rp_blven.tip_comprobante
      and cod_oficina = rp_blven.cod_oficina;
  exception
     when others then
        raise_application_error(-20000,'Error en obtener datos. '||Sqlerrm);
  end;
  
   insert into cb_lib_ventas(
      nro_factura, nro_timbrado, fecha, cod_oficina,
      tip_comprobante, tip_venta, cod_persona,  nom_completo,
      nro_documento, mto_exento, mto_gravado_5, mto_gravado_10,
      impuesto_5, impuesto_10, dig_verificador,
      nro_fac_referencia, nro_tim_referencia, direccion, telefono,
      fec_vig_timbrado, cod_moneda, can_cuota, fec_ini_timbrado, nro_aut_timbrado, tip_origen,
      serie, fec_aut_timbrado, fec_fac_referencia)
   values(
      rp_blven.nro_factura, rp_blven.nro_timbrado, rp_blven.fecha, rp_blven.cod_oficina,
      rp_blven.tip_comprobante, rp_blven.tip_venta, rp_blven.cod_persona, rp_blven. nom_completo,
      rp_blven.nro_documento, rp_blven.mto_exento, rp_blven.mto_gravado_5, rp_blven.mto_gravado_10,
      rp_blven.impuesto_5, rp_blven.impuesto_10, rp_blven.dig_verificador,
      rp_blven.nro_fac_referencia, rp_blven.nro_tim_referencia, rp_blven.direccion, rp_blven.telefono,
      rp_blven.fec_vig_timbrado, rp_blven.cod_moneda, rp_blven.can_cuota, v_fec_ini_timbrado, v_nro_aut_timbrado,
      rp_blven.tip_origen, rp_blven.serie, rp_blven.fec_aut_timbrado, rp_blven.fec_fac_referencia);
END;
/* Insertar detalle del Libro Venta */
PROCEDURE PR_INS_LIB_VEN_DET
 (RP_BLVDE IN CB_LIB_VENTAS_DET%ROWTYPE
 )
 IS
 v_fec_factura     cb_lib_ventas.fecha%type;
 v_cod_persona     cb_lib_ventas.cod_persona%type;
 v_cod_oficina     cb_lib_ventas.cod_oficina%type;
 v_cod_moneda      cb_lib_ventas.cod_moneda%type;
 v_monto           number;
 v_cod_mon_loc     ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_local;
  --DYDMR-7237 - Incidencia SAU - ITGF - Cobro en el Desembolso
 v_tra_iva_conf    ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('TRA_IVA_CONFIGURADO');

begin
   insert into cb_lib_ventas_det(
      fecha, hora, cod_usuario, nro_factura, nro_timbrado,
      cod_ofi_origen, cod_mod_padre, cod_mad_padre, cod_tra_padre,
      nro_documento, descripcion,
      cod_moneda, mto_exento, mto_exento_gs, mto_gravado_5,
      mto_gra_5_gs, mto_gravado_10, mto_gra_10_gs, impuesto_5,
      impuesto_5_gs, impuesto_10, impuesto_10_gs, cotizacion, nro_secuencia, nro_cuenta,
      aju_impuesto_5, aju_impuesto_10,
      cod_modulo,cod_modalidad,cod_transaccion, tip_comprobante)
   values(
      rp_blvde.fecha, rp_blvde.hora, rp_blvde.cod_usuario, rp_blvde.nro_factura, rp_blvde.nro_timbrado,
      rp_blvde.cod_ofi_origen, rp_blvde.cod_mod_padre, rp_blvde.cod_mad_padre, rp_blvde.cod_tra_padre,
      rp_blvde.nro_documento, rp_blvde.descripcion,
      rp_blvde.cod_moneda, rp_blvde.mto_exento, rp_blvde.mto_exento_gs, rp_blvde.mto_gravado_5,
      rp_blvde.mto_gra_5_gs, rp_blvde.mto_gravado_10, rp_blvde.mto_gra_10_gs, rp_blvde.impuesto_5,
      rp_blvde.impuesto_5_gs, rp_blvde.impuesto_10, rp_blvde.impuesto_10_gs, rp_blvde.cotizacion, rp_blvde.nro_secuencia,
      rp_blvde.nro_cuenta, rp_blvde.aju_impuesto_5, rp_blvde.aju_impuesto_10,
      rp_blvde.cod_modulo,rp_blvde.cod_modalidad,rp_blvde.cod_transaccion, rp_blvde.tip_comprobante);
   --DYDMR-7237 - Incidencia SAU - ITGF - Cobro en el Desembolso
   if ((rp_blvde.cod_tra_padre = 358 and  (instr(nvl(v_tra_iva_conf, '0'), ','||rp_blvde.cod_transaccion||',') > 0))
     or rp_blvde.cod_transaccion = 710) then
     -- DYDMR-5363
     -- Se obtienen datos de la cabecera de factura.
     begin
       select a.fecha, a.cod_persona, a.cod_oficina, a.cod_moneda
         into v_fec_factura, v_cod_persona, v_cod_oficina, v_cod_moneda
         from cb_lib_ventas a
        where a.nro_timbrado = rp_blvde.nro_timbrado
          and a.nro_factura = rp_blvde.nro_factura
          and a.tip_comprobante = 'F'
          and a.tip_venta = 'CR';
     exception
       when others then
         null;
     end;
     -- Se obtiene el monto cobrado de la cuenta
     if v_cod_persona is not null then
       begin
         select round(decode(b.tip_monto,
                             'N',
                             decode(c.cod_moneda,
                                    v_cod_mon_loc,
                                    (nvl(c.mto_capital, 0) - nvl(b.monto, 0)),
                                    (nvl(c.mto_capital, 0) - nvl(b.monto, 0)) *
                                    rp_blvde.cotizacion),
                             decode(c.cod_moneda,
                                    v_cod_mon_loc,
                                    abs(b.mto_cargo),
                                    abs(b.mto_cargo) * rp_blvde.cotizacion)),
                      0)
           into v_monto
           from pr_cta_prestamos c, pr_solicitudes b
          where c.nro_cuenta = rp_blvde.nro_cuenta
            and b.nro_solicitud = c.nro_solicitud;
         exception
           when others then
             v_monto := 0;
       end;
       -- Se insertan los datos a considerarse para la generación de Recibos.
       begin
         insert into cb_fac_recibos(nro_timbrado,
                                    nro_factura,
                                    fec_movimiento,
                                    hor_movimiento,
                                    usu_movimiento,
                                    fecha,
                                    cod_persona,
                                    cod_mod_padre,
                                    cod_mad_padre,
                                    cod_tra_padre,
                                    cod_transaccion,
                                    cod_oficina,
                                    cod_moneda,
                                    nro_cuenta,
                                    cotizacion,
                                    monto,
                                    nro_cuota)
                             values(rp_blvde.nro_timbrado,
                                    rp_blvde.nro_factura,
                                    rp_blvde.fecha,
                                    rp_blvde.hora,
                                    rp_blvde.cod_usuario,
                                    v_fec_factura,
                                    v_cod_persona,
                                    rp_blvde.cod_mod_padre,
                                    rp_blvde.cod_mad_padre,
                                    rp_blvde.cod_tra_padre,
                                    rp_blvde.cod_transaccion,
                                    v_cod_oficina,
                                    v_cod_moneda,
                                    rp_blvde.nro_cuenta,
                                    rp_blvde.cotizacion,
                                    v_monto,
                                    rp_blvde.nro_documento); --DYDMR-10261
       exception
         when dup_val_on_index then
           null;
         when others then
           null;
       end;
     end if;
   end if;
end;
/* Genera libro venta de las operaciones. */
PROCEDURE PR_GEN_FACTURA
 (P_COD_PERSONA IN VARCHAR2 := null
 ,P_FECHA IN DATE := null
 ,P_HORA IN varchar2 := null
 ,P_COD_USUARIO IN VARCHAR2 := null
 )
 IS
--- Variables de corte de control
   v_cod_persona  cb_lib_ventas.cod_persona%type;
   v_nro_tim_fac  cb_lib_ventas.nro_timbrado%type;
   v_fec_vig_tim  date;
   rv_blven       cb_lib_ventas%rowtype;
   rv_blvde       cb_lib_ventas_det%rowtype;
   v_nro_factura  cb_lib_ventas.nro_factura%type;
   v_fec_proceso  date;
   v_nro_lin_fac  number(8);  -- Nro. de Lineas que puede tener una factura
   v_nro_linea    number(8);  -- Cantidad de lineas impresas de la factura
   v_cod_oficina  number(4);
   v_tip_venta    cb_lib_ventas.tip_venta%type;
   v_cod_mon_factura varchar2(5);
   v_tip_imp      ge_par_generales.tip_implementacion%type;
   v_pun_expedicion number(3); -- Punto de Expedicion del comprobante
   v_lugar varchar2(1000) := null;
   v_cod_ofi_hacienda ba_oficinas.cod_oficina%type;
   v_borrado          NUMBER := 0; --bandera para borrar cabecera cb_lib_ventas_tmp
   v_max_cuota        cb_lib_ventas.can_cuota%type := 0;
   v_auxiliar         cb_lib_ventas.can_cuota%type := 0;
   --> CNFFAOCA-1-CNF-MB: 11/12/2015, Facturas de Operaciones de Cambios
   v_tip_comprobante  cb_lib_ventas.tip_comprobante%type;
   v_fec_aut_timbrado cb_par_comprobantes.fec_ini_timbrado%type;
   v_nro_documento    cb_lib_ventas_det.nro_documento%TYPE;
   v_gen_dos_fac_arb  varchar2(1) := nvl(fug_obt_pardinamico('CON_GEN_FAC_ARB_VENTA', NULL, NULL, NULL,NULL),'N');
   v_cod_moneda       cb_lib_ventas_det.cod_moneda%TYPE;
   v_monto            cb_lib_ventas_det.mto_exento%TYPE;
   v_descripcion      cb_lib_ventas_det.descripcion%TYPE;
   v_cotizacion       cb_lib_ventas_det.cotizacion%TYPE;
   v_can_cuotas       cb_lib_ventas_det.can_cuotas%TYPE;
   v_mensaje          varchar2(100);
   v_contador         number;
   --- Cursor de movimientos de la persona por factura
   cursor c_reversados is
   select v.cod_persona, v.fecha, v.hora, v.cod_usuario, v.nro_secuencia, v.cod_ofi_origen,
          v.tip_comprobante, v.tip_venta,
          v.cod_mod_padre, v.cod_mad_padre, v.cod_tra_padre,
          v.descripcion,
          v.cod_moneda, v.mto_exento, v.mto_exento_gs, v.mto_gravado_5, v.mto_gra_5_gs,
          v.mto_gravado_10, v.mto_gra_10_gs, v.impuesto_5, v.impuesto_5_gs,
          v.impuesto_10, v.impuesto_10_gs, v.cotizacion, nvl(c.cod_oficina,v.cod_ofi_origen) cod_oficina, v.nom_completo,
          v.nro_doc_persona nro_documento, p.tipo, v.nro_cuenta,
          v.nro_documento nro_recibo, v.rowid fila, v.aju_impuesto_5, v.aju_impuesto_10,
          decode(nvl(fue_per_dat_adicional(nvl(p_cod_persona,v.cod_persona),'TIP_FACTURACION'),'L'),'L','GS',v.cod_moneda) cod_mon_factura,
          v.can_cuota, v.cod_modulo,v.cod_modalidad,v.cod_transaccion,p.tip_iva /*DYDMR-5605 NAF 03/2017*/
     from cb_lib_ventas_det_tmp v,  ge_clientes c, ba_personas p
    where nvl(v.reversado,'N') = 'N'
      and nvl(v.tip_comprobante,'X') <> 'C'  -- CNFNORMA-18/RABP/10-2016: No debe incluir operaciones de cambio
      and c.cod_persona(+) =  v.cod_persona
      and p.cod_persona(+)  = v.cod_persona
      --- Verificar si tiene parámetros
      and ((v.cod_persona  = nvl(p_cod_persona,v.cod_persona)) or
           (v.cod_persona is null and p_cod_persona is null))
      and v.fecha        = nvl(p_fecha,v.fecha)
      and v.hora         = nvl(p_hora,v.hora)
      and v.error is null  -- solo tomas los que no tienen error
      and v.cod_usuario  = nvl(p_cod_usuario,v.cod_usuario)
      AND v.Cod_Mod_Padre <> 7 
      --and v.cod_persona is not null  --Incluir registros que no tienen COD_PERSONA, 30/01/2010
   order by v.nom_completo, nvl(v.cod_persona,'0'), cod_mon_factura, v.tip_venta, v.fecha, v.hora;
         
          --- Cursor de movimientos de cambios
      CURSOR c_ope_cambios IS
         select v.cod_persona, v.fecha, v.hora, v.cod_usuario, v.nro_secuencia, v.cod_ofi_origen,
          v.tip_comprobante, v.tip_venta,
          v.cod_mod_padre, v.cod_mad_padre, v.cod_tra_padre,
          v.descripcion,
          v.cod_moneda, v.mto_exento, v.mto_exento_gs, v.mto_gravado_5, v.mto_gra_5_gs,
          v.mto_gravado_10, v.mto_gra_10_gs, v.impuesto_5, v.impuesto_5_gs,
          v.impuesto_10, v.impuesto_10_gs, v.cotizacion, nvl(c.cod_oficina,v.cod_ofi_origen) cod_oficina, v.nom_completo,
          v.nro_doc_persona nro_documento, p.tipo, v.nro_cuenta,
          v.nro_documento nro_recibo, v.rowid fila, v.aju_impuesto_5, v.aju_impuesto_10,
          decode(nvl(fue_per_dat_adicional(nvl(p_cod_persona,v.cod_persona),'TIP_FACTURACION'),'L'),'L','GS',v.cod_moneda) cod_mon_factura,
          v.can_cuota, v.cod_modulo,v.cod_modalidad,v.cod_transaccion,p.tip_iva
           FROM cb_lib_ventas_det_tmp v, ge_clientes c, ba_personas p
          WHERE nvl(v.reversado, 'N') = 'N'
            AND c.cod_persona(+) = v.cod_persona
            AND p.cod_persona(+) = v.cod_persona
               --- Verificar si tiene parámetros
            AND ((v.cod_persona = nvl(p_cod_persona, v.cod_persona)) OR
                 (v.cod_persona IS NULL AND p_cod_persona IS NULL))
            AND v.fecha = nvl(p_fecha, v.fecha)
            AND v.hora = nvl(p_hora, v.hora)
            AND v.error IS NULL -- solo tomas los que no tienen error
            AND v.cod_usuario = nvl(p_cod_usuario, v.cod_usuario)
            AND v.cod_persona IS NOT NULL
            AND v.Cod_Mod_Padre = 7 --Se incluyen por separado operaciones de cambios resolucion de la set 92
          ORDER BY v.nom_completo,
                   nvl(v.cod_persona, '0'),
                   decode(nvl(fue_per_dat_adicional(nvl(p_cod_persona, v.cod_persona),
                                                    'TIP_FACTURACION'), 'L'), 'L', 'GS', v.cod_moneda),
                   v.tip_venta,
                   v.fecha,
                   v.hora;
   TYPE cursor1_type IS TABLE OF c_reversados%ROWTYPE;
   reg cursor1_type;

BEGIN
   -- Registrar el nombre en action
   DBMS_APPLICATION_INFO.SET_ACTION('PAB_IVA.PR_GEN_FACTURA');
   DBMS_APPLICATION_INFO.SET_CLIENT_INFO('PR_GEN_FACTURA, Iniciando');
   Begin pre_ini_aplicacion;pae_cnf.G_COD_MODULO:=1;end;
   v_cod_persona := '.';
   v_tip_venta   := '.';
   v_cod_mon_factura := '.';
   v_nro_lin_fac := 45;   -- esta es la cantidad de lineas por factura que se puede imprimir
   v_nro_linea   := 0;
   --v_fec_proceso := pag_cal.fu_obt_fec_actual(1);
   v_tip_imp     := fug_obt_tip_implementacion;
   --> CNFFAOCA-1-CNF-MB: 11/12/2015, Facturas de Operaciones de Cambios
   --v_pun_expedicion := fu_obt_pun_expedicion('F');
   v_contador := 0;
   OPEN c_reversados;
      LOOP
         FETCH c_reversados BULK COLLECT
            INTO reg LIMIT 30000;
         FOR i IN 1 .. reg.count LOOP
         ---FOR reg IN c_reversados LOOP  * Se comenta pues ahora se utiliza el método Bulk Collect * RM --
            -- Monitoreo del avance cada 10000 registros 
            IF MOD(i, 10000) = 0 OR i = reg.COUNT THEN
                v_contador := v_contador +  1;
                v_mensaje := v_contador||' - c_reversados-registro ' || i || ' de ' || reg.COUNT;
                DBMS_APPLICATION_INFO.SET_CLIENT_INFO(v_mensaje);
            END IF;
      v_fec_proceso     :=reg(i).fecha;
      v_lugar := 'c_reversados '||reg(i).cod_persona;
      --30/06/2010: No procesar los registros marcados
      --con tipo comprobante ='X', corresponden a Iva s/Interes vencido ya cobrado y facturado.
      If reg(i).tip_comprobante = 'X' then
        --Si es fin de mes borrar los registros con tipo comprobante ='X'
        if pag_cal.G_FEC_ACTUAL = pag_cal.G_ULT_DIA_MES_HABIL then
          delete cb_lib_ventas_det_tmp
           where rowid = reg(i).fila;
       v_borrado := 1;
        end if;
      else
        --- Corte de control
        if nvl(v_cod_persona,'-1') <> nvl(reg(i).cod_persona,'-1')
           or nvl(v_tip_venta,'.') <> nvl(reg(i).tip_venta,'.')
           or nvl(v_cod_mon_factura,'.') <> nvl(reg(i).cod_mon_factura,'.')
           --> CNFFAOCA-1-CNF-MB: 11/12/2015, Facturas de Operaciones de Cambios
           or nvl(v_tip_comprobante,'Z') <> nvl(reg(i).tip_comprobante,'Z')
           or v_nro_linea + 1 > v_nro_lin_fac then
           
           v_cod_oficina := reg(i).cod_oficina; -- Modificado 05/03/2010 por ICL - para que tome oficina del cliente
           --Si existe Oficina Generica
           IF v_ofi_pto_generico <> -1 THEN
             v_cod_oficina := v_ofi_pto_generico;
           END IF;
           v_pun_expedicion := fu_obt_pun_expedicion('F', v_cod_oficina);
           v_cod_ofi_hacienda := fug_obt_pardinamico('COD_OFI_HACIENDA', null, null, null, v_cod_oficina);
           if v_cod_ofi_hacienda is null then
             raise_application_error(-20000, 'No se ha definido el parametro COD_OFI_HACIENDA para la oficina '||v_cod_oficina);
           end if;
           -- Insertar cabecera para la factura
           pab_iva.pr_obt_nro_factura(v_cod_oficina, v_fec_proceso, 'F', v_nro_factura, 
                                      v_nro_tim_fac, v_fec_vig_tim);--Modificado ICL 12/03/2010 xq la numeracion es unica para todas las oficinas
           begin
               select fec_ini_timbrado
                 into v_fec_aut_timbrado
                 from cb_par_comprobantes a
                where nro_timbrado = v_nro_tim_fac
                  and tipo = 'F'
                  and cod_oficina = v_cod_oficina;
             exception
               when no_data_found then
                 raise_application_error(-20000,'No se ha encontrado fecha de inicio de timbrado
                                                 para la ofic. '||v_cod_oficina||' Tip. compr. Fact.' ||sqlerrm);
               when others then
                 raise_application_error(-20000,v_lugar||sqlerrm);
             end;
           --- Insertar cabecera
           rv_blven.nro_factura        := lpad(v_cod_ofi_hacienda,3,'0')||
                                            '-'||lpad(v_pun_expedicion,3,'0')||
                                            '-'||lpad(to_char(v_nro_factura),7,'0');
           v_nro_fac_retorno           := rv_blven.nro_factura;
           rv_blven.nro_timbrado       := v_nro_tim_fac;
           rv_blven.fec_vig_timbrado   := v_fec_vig_tim;
           rv_blven.fec_aut_timbrado   := v_fec_aut_timbrado;
           rv_blven.fecha              := v_fec_proceso;
           rv_blven.cod_oficina        := v_cod_oficina;
           rv_blven.tip_comprobante    := 'F';
           rv_blven.tip_venta          := reg(i).tip_venta;
           if reg(i).cod_persona is not null then
             rv_blven.cod_persona      := reg(i).cod_persona;
             rv_blven.nom_completo     := reg(i).nom_completo;
             rv_blven.nro_documento    := reg(i).nro_documento;
             rv_blven.dig_verificador  := null;
             if reg(i).tipo = 'J' then
               begin
                 if instr(reg(i).nro_documento,'-') > 0 then
                   rv_blven.nro_documento   := substr(reg(i).nro_documento,1,instr(reg(i).nro_documento,'-')-1);
                   rv_blven.dig_verificador := substr(reg(i).nro_documento,-1);
                 end if;
               exception
                  when others then
                     rv_blven.nro_documento := reg(i).nro_documento;
                     rv_blven.dig_verificador := NULL;
               end;
             else
               begin
                 if instr(reg(i).nro_documento,'-') > 0 then
                    rv_blven.nro_documento   := substr(reg(i).nro_documento,1,instr(reg(i).nro_documento,'-')-1);
                    rv_blven.dig_verificador := substr(reg(i).nro_documento,-1);
                 else
                    -- DYDMR-5605 NAF 03/2017 Si el cliente es no contribuyente dig_verificador es NULL
                    if reg(i).tip_iva = 'NC' then
                      rv_blven.dig_verificador := NULL;
                    else
                      rv_blven.dig_verificador := fue_obt_ruc_dig_verificador(reg(i).nro_documento);
                    end if;
                 end if;
               exception
                  when others then
                     rv_blven.nro_documento := reg(i).nro_documento;
                     rv_blven.dig_verificador := NULL;
               end;
             end if;
             rv_blven.direccion        := fue_obt_dir_principa(reg(i).cod_persona);
             rv_blven.telefono         := fue_obt_tel_principa(reg(i).cod_persona);
             if rv_blven.nro_documento is null then
               rv_blven.nro_documento  := reg(i).nro_documento;
             end if;
           else
             rv_blven.cod_persona      := null;
             rv_blven.nom_completo     := 'SIN NOMBRE';
             rv_blven.nro_documento    := 'X';
             rv_blven.dig_verificador  := null;
             rv_blven.direccion        := null;
             rv_blven.telefono         := null;
           end if;
           rv_blven.cod_moneda         := reg(i).cod_mon_factura;
           rv_blven.can_cuota          := 0;
           rv_blven.serie              := IT.FUG_OBT_SERIE(nvl(reg(i).tip_comprobante, 'F'),
                                                           v_cod_oficina,
                                                           v_nro_tim_fac);
           pab_iva.PR_INS_LIB_VEN_CAB(rv_blven);
           --- Obs. Los totales de la cabecera son por trigger
           v_nro_linea   := 0;
           v_cod_persona := reg(i).cod_persona;
           v_tip_venta   := reg(i).tip_venta;
           v_cod_mon_factura := reg(i).cod_mon_factura;
           v_max_cuota := 0;
           v_tip_comprobante := reg(i).tip_comprobante;
        end if;
        -- verificar la mayor cuota y actualizar cb_lib_ventas. CNF 16/03/15
        v_auxiliar := reg(i).can_cuota;
        if v_auxiliar > v_max_cuota then
           v_max_cuota := v_auxiliar;
           update cb_lib_ventas c
              set c.can_cuota = v_max_cuota
            where c.nro_factura  = rv_blven.nro_factura
              and c.nro_timbrado = rv_blven.nro_timbrado;
        end if;
           v_auxiliar := 0;
        --
        v_nro_linea             := v_nro_linea + 1;
        --- Insertar detalles
        rv_blvde.fecha          := rv_blven.fecha;--reg(i).fecha;
        rv_blvde.hora           := reg(i).hora;
        rv_blvde.cod_usuario    := reg(i).cod_usuario;
        rv_blvde.nro_secuencia  := reg(i).nro_secuencia;
        rv_blvde.nro_factura    := rv_blven.nro_factura;
        rv_blvde.nro_timbrado   := rv_blven.nro_timbrado;
        rv_blvde.cod_ofi_origen := reg(i).cod_ofi_origen;
        rv_blvde.cod_mod_padre  := reg(i).cod_mod_padre;
        rv_blvde.cod_mad_padre  := reg(i).cod_mad_padre;
        rv_blvde.cod_tra_padre  := reg(i).cod_tra_padre;
        rv_blvde.nro_documento  := reg(i).nro_recibo;
        rv_blvde.descripcion    := reg(i).descripcion;
        rv_blvde.cod_moneda     := reg(i).cod_moneda;
        rv_blvde.mto_exento     := reg(i).mto_exento;
        rv_blvde.mto_exento_gs  := reg(i).mto_exento_gs;
        rv_blvde.mto_gravado_5  := reg(i).mto_gravado_5;
        rv_blvde.mto_gra_5_gs   := reg(i).mto_gra_5_gs;
        rv_blvde.mto_gravado_10 := reg(i).mto_gravado_10;
        rv_blvde.mto_gra_10_gs  := reg(i).mto_gra_10_gs;
        rv_blvde.impuesto_5     := reg(i).impuesto_5;
        rv_blvde.impuesto_5_gs  := reg(i).impuesto_5_gs;
        rv_blvde.impuesto_10    := reg(i).impuesto_10;
        rv_blvde.impuesto_10_gs := reg(i).impuesto_10_gs;
        rv_blvde.cotizacion     := reg(i).cotizacion;
        rv_blvde.nro_cuenta     := reg(i).nro_cuenta;
        rv_blvde.aju_impuesto_5 := reg(i).aju_impuesto_5;
        rv_blvde.aju_impuesto_10:= reg(i).aju_impuesto_10;
    --Transac. Mod. Moda.
        rv_blvde.cod_modulo:= reg(i).cod_modulo;
        rv_blvde.cod_modalidad:= reg(i).cod_modalidad;
        rv_blvde.cod_transaccion:= reg(i).cod_transaccion;
        rv_blvde.tip_comprobante:= 'F';
        pab_iva.PR_INS_LIB_VEN_DET(rv_blvde);
      --- Eliminar notas de creditos temporales
      delete cb_lib_ventas_det_tmp
        where rowid = reg(i).fila;
    v_borrado := 1;
     End if;
   end loop;
   EXIT WHEN c_reversados%NOTFOUND;
 END LOOP;
  close c_reversados;

      OPEN c_ope_cambios;
      LOOP
         FETCH c_ope_cambios BULK COLLECT
            INTO reg LIMIT 2500;
         FOR i IN 1 .. reg.count LOOP
            -- Monitoreo del avance cada 100 registros
            IF MOD(i, 100) = 0 OR i = reg.COUNT THEN
                v_mensaje := 'c_ope_cambios-registro ' || i || ' de ' || reg.COUNT;
                DBMS_APPLICATION_INFO.SET_CLIENT_INFO(v_mensaje);
            END IF;
		      v_fec_proceso     :=reg(i).fecha; --pag_cal.fu_obt_fec_actual(1);
          v_lugar := 'c_ope_cambios '||reg(i).cod_persona;
            --- Corte de control
            IF nvl(v_tip_venta, '.') <> nvl(reg(i).tip_venta, '.') OR
               nvl(v_cod_mon_factura, '.') <> nvl(reg(i).cod_mon_factura, '.') OR
               nvl(v_nro_documento, 0) <> nvl(reg(i).nro_recibo, 0) OR
               v_nro_linea + 1 > v_nro_lin_fac THEN
            v_cod_oficina := reg(i).cod_oficina; -- Modificado 05/03/2010 por ICL - para que tome oficina del cliente
           --Si existe Oficina Generica
           IF v_ofi_pto_generico <> -1 THEN
             v_cod_oficina := v_ofi_pto_generico;
           END IF;
           v_pun_expedicion := fu_obt_pun_expedicion('F', v_cod_oficina);
           v_cod_ofi_hacienda := fug_obt_pardinamico('COD_OFI_HACIENDA', null, null, null, v_cod_oficina);
           if v_cod_ofi_hacienda is null then
             raise_application_error(-20000, 'No se ha definido el parametro COD_OFI_HACIENDA para la oficina '||v_cod_oficina);
           end if;
           -- Insertar cabecera para la factura
              -- Insertar cabecera para la factura
           pab_iva.pr_obt_nro_factura(v_cod_oficina, v_fec_proceso, 'F', v_nro_factura, 
                                      v_nro_tim_fac, v_fec_vig_tim);--Modificado ICL 12/03/2010 xq la numeracion es unica para todas las oficinas  --- Insertar cabecera
               begin
               select fec_ini_timbrado
                 into v_fec_aut_timbrado
                 from cb_par_comprobantes a
                where nro_timbrado = v_nro_tim_fac
                  and tipo = 'F'
                  and cod_oficina = v_cod_oficina;
             exception
               when no_data_found then
                 raise_application_error(-20000,'No se ha encontrado fecha de inicio de timbrado
                                                 para la ofic. '||v_cod_oficina||' Tip. compr. Fact.' ||sqlerrm);
               when others then
                 raise_application_error(-20000,v_lugar||sqlerrm);
             end;
               rv_blven.nro_factura := lpad(v_cod_ofi_hacienda,3,'0')||
                                            '-'||lpad(v_pun_expedicion,3,'0')||
                                            '-'||lpad(to_char(v_nro_factura),7,'0');                                    
               v_nro_fac_retorno         := rv_blven.nro_factura;
               rv_blven.nro_timbrado     := v_nro_tim_fac;
               rv_blven.fec_vig_timbrado := v_fec_vig_tim;
               rv_blven.fec_aut_timbrado := v_fec_aut_timbrado;
               rv_blven.fecha            := v_fec_proceso;
               rv_blven.cod_oficina      := v_cod_oficina;
               rv_blven.tip_comprobante  := nvl(reg(i).tip_comprobante, 'F');
               rv_blven.tip_venta        := reg(i).tip_venta;
               IF reg(i).cod_persona IS NOT NULL THEN
                  rv_blven.cod_persona     := reg(i).cod_persona;
                  rv_blven.nom_completo    := reg(i).nom_completo;
                  rv_blven.nro_documento   := reg(i).nro_documento;
                  rv_blven.dig_verificador := NULL;
                  IF reg(i).tipo = 'J' THEN
                     IF instr(rv_blven.nro_documento, '-') > 0 THEN
                        rv_blven.nro_documento   := substr(reg(i).nro_documento, 1,
                                                           instr(reg(i).nro_documento, '-') - 1);
                        rv_blven.dig_verificador := substr(reg(i).nro_documento, -1);
                     END IF;
                  ELSE
                    ----> IF lf_es_contribuyente(reg(i).cod_persona, reg(i).tipo) = 'S' THEN
                        IF instr(rv_blven.nro_documento, '-') > 0 THEN
                           rv_blven.nro_documento   := substr(reg(i).nro_documento, 1,
                                                              instr(reg(i).nro_documento, '-') - 1);
                           rv_blven.dig_verificador := substr(reg(i).nro_documento, -1);
                        ELSE
                          --  Si el cliente es no contribuyente dig_verificador es NULL
                            IF reg(i).tip_iva = 'NC' then
                               rv_blven.dig_verificador := NULL;
                            ELSE
                               rv_blven.dig_verificador := substr(reg(i).nro_documento, -1);
                            END IF;
                        END IF;
                    ----> END IF;
                  END IF;
                  rv_blven.direccion := fue_obt_dir_principa(reg(i).cod_persona);
                  rv_blven.telefono  := fue_obt_tel_principa(reg(i).cod_persona);
                  IF rv_blven.nro_documento IS NULL THEN
                     rv_blven.nro_documento := reg(i).nro_documento;
                  END IF;
               END IF;
               rv_blven.cod_moneda         := reg(i).cod_mon_factura;
               rv_blven.can_cuotas         := reg(i).can_cuota;
               rv_blven.serie              := IT.FUG_OBT_SERIE(nvl(reg(i).tip_comprobante, 'F'),
                                                               v_cod_oficina,
                                                               v_nro_tim_fac);
               pab_iva.pr_ins_lib_ven_cab(rv_blven);
               --- Obs. Los totales de la cabecera son por trigger
               v_nro_linea       := 0;
               v_cod_persona     := reg(i).cod_persona;
               v_tip_venta       := reg(i).tip_venta;
               v_cod_mon_factura := reg(i).cod_mon_factura;
               v_nro_documento   := reg(i).nro_recibo;
            END IF;
            v_nro_linea := v_nro_linea + 1;
            --- Insertar detalles
            rv_blvde.fecha           := reg(i).fecha;
            rv_blvde.hora            := reg(i).hora;
            rv_blvde.cod_usuario     := reg(i).cod_usuario;
            rv_blvde.nro_secuencia   := reg(i).nro_secuencia;
            rv_blvde.nro_factura     := rv_blven.nro_factura;
            rv_blvde.nro_timbrado    := rv_blven.nro_timbrado;
            rv_blvde.cod_ofi_origen  := reg(i).cod_ofi_origen;
            rv_blvde.cod_mod_padre   := reg(i).cod_mod_padre;
            rv_blvde.cod_mad_padre   := reg(i).cod_mad_padre;
            rv_blvde.cod_tra_padre   := reg(i).cod_tra_padre;
            rv_blvde.nro_documento   := reg(i).nro_recibo;
            rv_blvde.descripcion     := reg(i).descripcion;
            rv_blvde.cod_moneda      := reg(i).cod_moneda;
            rv_blvde.mto_exento      := reg(i).mto_exento;
            rv_blvde.mto_exento_gs   := reg(i).mto_exento_gs;
            rv_blvde.mto_gravado_5   := reg(i).mto_gravado_5;
            rv_blvde.mto_gra_5_gs    := reg(i).mto_gra_5_gs;
            rv_blvde.mto_gravado_10  := reg(i).mto_gravado_10;
            rv_blvde.mto_gra_10_gs   := reg(i).mto_gra_10_gs;
            rv_blvde.impuesto_5      := reg(i).impuesto_5;
            rv_blvde.impuesto_5_gs   := reg(i).impuesto_5_gs;
            rv_blvde.impuesto_10     := reg(i).impuesto_10;
            rv_blvde.impuesto_10_gs  := reg(i).impuesto_10_gs;
            rv_blvde.cotizacion      := reg(i).cotizacion;
            rv_blvde.nro_cuenta      := reg(i).nro_cuenta;
            rv_blvde.aju_impuesto_5  := reg(i).aju_impuesto_5;
            rv_blvde.aju_impuesto_10 := reg(i).aju_impuesto_10;
             --Transac. Mod. Moda.
            rv_blvde.cod_modulo:= reg(i).cod_modulo;
            rv_blvde.cod_modalidad:= reg(i).cod_modalidad;
            rv_blvde.cod_transaccion:= reg(i).cod_transaccion;
            rv_blvde.tip_comprobante := 'F';
            pab_iva.pr_ins_lib_ven_det(rv_blvde);

            --Genera otra factura por la venta cuando el parametro CON_GEN_FAC_ARBITRAJE = 'S'
            If nvl(v_gen_dos_fac_arb,'N') = 'S' and reg(i).cod_mad_padre = 73 then
               --- Insertar cabecera para la factura
                 pab_iva.pr_obt_nro_factura(v_cod_oficina, v_fec_proceso, 'F', v_nro_factura, 
                                      v_nro_tim_fac, v_fec_vig_tim);
               --- Insertar cabecera
               rv_blven.nro_factura      := lpad(v_cod_ofi_hacienda,3,'0')||
                                            '-'||lpad(v_pun_expedicion,3,'0')||
                                            '-'||lpad(to_char(v_nro_factura),7,'0'); 
               v_nro_fac_retorno         := rv_blven.nro_factura;
               rv_blven.nro_timbrado     := v_nro_tim_fac;
               rv_blven.fec_vig_timbrado := v_fec_vig_tim;
               rv_blven.fec_aut_timbrado := v_fec_aut_timbrado;
               rv_blven.fecha            := v_fec_proceso;
               rv_blven.cod_oficina      := v_cod_oficina;
               rv_blven.tip_comprobante  := 'F';
               rv_blven.tip_venta        := reg(i).tip_venta;
               IF reg(i).cod_persona IS NOT NULL THEN
                  rv_blven.cod_persona     := reg(i).cod_persona;
                  rv_blven.nom_completo    := reg(i).nom_completo;
                  rv_blven.nro_documento   := reg(i).nro_documento;
                  rv_blven.dig_verificador := NULL;
                  IF reg(i).tipo = 'J' THEN
                     IF instr(rv_blven.nro_documento, '-') > 0 THEN
                        rv_blven.nro_documento   := substr(reg(i).nro_documento, 1,
                                                           instr(reg(i).nro_documento, '-') - 1);
                        rv_blven.dig_verificador := substr(reg(i).nro_documento,-1);
                     END IF;
                  ELSE
                    ----> IF lf_es_contribuyente(reg(i).cod_persona, reg(i).tipo) = 'S' THEN
                        IF instr(rv_blven.nro_documento, '-') > 0 THEN
                           rv_blven.nro_documento   := substr(reg(i).nro_documento, 1,
                                                              instr(reg(i).nro_documento, '-') - 1);
                           rv_blven.dig_verificador := substr(reg(i).nro_documento, -1);
                        ELSE
                          rv_blven.dig_verificador := substr(reg(i).nro_documento, -1);
                        END IF;
                    ----> END IF;
                  END IF;
                  rv_blven.direccion := fue_obt_dir_principa(reg(i).cod_persona);
                  rv_blven.telefono  := fue_obt_tel_principa(reg(i).cod_persona);
                  IF rv_blven.nro_documento IS NULL THEN
                     rv_blven.nro_documento := reg(i).nro_documento;
                  END IF;
               END IF;
               rv_blven.cod_moneda         := reg(i).cod_mon_factura;
               rv_blven.can_cuotas         := reg(i).can_cuota;
               rv_blven.serie              := IT.FUG_OBT_SERIE(nvl(reg(i).tip_comprobante, 'F'),
                                                               v_cod_oficina,
                                                               v_nro_tim_fac);
               pab_iva.pr_ins_lib_ven_cab(rv_blven);
               --- Obs. Los totales de la cabecera son por trigger
               v_nro_linea       := 0;
               v_cod_persona     := reg(i).cod_persona;
               v_tip_venta       := reg(i).tip_venta;
               v_cod_mon_factura := reg(i).cod_mon_factura;
               v_nro_documento   := reg(i).nro_recibo;
               v_nro_linea := v_nro_linea + 1;
               --- Insertar detalles
               begin
                 SELECT  m.cod_moneda,
                        decode(reversado, 'S', m.monto * -1, decode(cod_modulo, 5, abs(m.monto), m.monto)) monto,
                        substr(FUG_OBT_DES_TRANSACCION(cod_modulo,cod_modalidad,cod_transaccion),1, 35),
                        decode(m.cotizacion, 0, NULL, m.cotizacion) cotizacion
                   into v_cod_moneda, v_monto, v_descripcion, v_cotizacion
                   FROM ge_movimientos m
                  WHERE m.cod_mod_padre = 7
                    AND m.estado = 'N'
                    AND m.fecha = reg(i).fecha
                    AND m.hora = reg(i).hora
                    AND m.cod_usuario = reg(i).cod_usuario
                    AND m.monto <> 0
                    AND (m.cod_mod_padre = 7 AND m.cod_transaccion NOT IN (760, 401, 901) AND nro_secuencia = 2)
                    AND nvl(m.cod_transaccion, 0) NOT IN (4050, 4052)
                    AND NOT EXISTS (SELECT 1
                           FROM ge_movimientos x
                          WHERE x.fecha = m.fecha
                            AND x.hora = m.hora
                            AND x.cod_usuario = m.cod_usuario
                            AND x.estado IN ('X', 'J', 'P')
                            AND nvl(x.reversado, 'N') = 'N');
               exception
                 when no_data_found then
                   null;
               end;
               rv_blvde.fecha           := reg(i).fecha;
               rv_blvde.hora            := reg(i).hora;
               rv_blvde.cod_usuario     := reg(i).cod_usuario;
               rv_blvde.nro_secuencia   := reg(i).nro_secuencia;
               rv_blvde.nro_factura     := rv_blven.nro_factura;
               rv_blvde.nro_timbrado    := rv_blven.nro_timbrado;
               rv_blvde.cod_ofi_origen  := reg(i).cod_ofi_origen;
               rv_blvde.cod_mod_padre   := reg(i).cod_mod_padre;
               rv_blvde.cod_mad_padre   := reg(i).cod_mad_padre;
               rv_blvde.cod_tra_padre   := reg(i).cod_tra_padre;
               rv_blvde.nro_documento   := reg(i).nro_recibo;
               rv_blvde.descripcion     := v_descripcion;
               rv_blvde.cod_moneda      := v_cod_moneda;
               rv_blvde.mto_exento      := v_monto;
               rv_blvde.mto_exento_gs   := round(nvl(v_monto, 0) * v_cotizacion, 0);
               rv_blvde.mto_gravado_5   := reg(i).mto_gravado_5;
               rv_blvde.mto_gra_5_gs    := reg(i).mto_gra_5_gs;
               rv_blvde.mto_gravado_10  := reg(i).mto_gravado_10;
               rv_blvde.mto_gra_10_gs   := reg(i).mto_gra_10_gs;
               rv_blvde.impuesto_5      := reg(i).impuesto_5;
               rv_blvde.impuesto_5_gs   := reg(i).impuesto_5_gs;
               rv_blvde.impuesto_10     := reg(i).impuesto_10;
               rv_blvde.impuesto_10_gs  := reg(i).impuesto_10_gs;
               rv_blvde.cotizacion      := v_cotizacion;
               rv_blvde.nro_cuenta      := reg(i).nro_cuenta;
               rv_blvde.aju_impuesto_5  := reg(i).aju_impuesto_5;
               rv_blvde.aju_impuesto_10 := reg(i).aju_impuesto_10;
                            --Transac. Mod. Moda.
               rv_blvde.cod_modulo:= reg(i).cod_modulo;
               rv_blvde.cod_modalidad:= reg(i).cod_modalidad;
               rv_blvde.cod_transaccion:= reg(i).cod_transaccion;
               rv_blvde.tip_comprobante := 'F';
               pab_iva.pr_ins_lib_ven_det(rv_blvde);
            End if;

            --- Eliminar notas de creditos temporales
            DELETE cb_lib_ventas_det_tmp WHERE ROWID = reg(i).fila;
         END LOOP;
         IF v_tip_venta = 'CR' THEN
            BEGIN
               SELECT MAX(can_cuotas)
                 INTO v_can_cuotas
                 FROM cb_lib_ventas_det t
                WHERE t.nro_factura = rv_blven.nro_factura
                  AND t.nro_timbrado = rv_blven.nro_timbrado;
               UPDATE cb_lib_ventas c
                  SET can_cuotas = v_can_cuotas
                WHERE c.nro_factura = rv_blven.nro_factura
                  AND c.tip_comprobante = rv_blven.tip_comprobante
                  AND c.nro_timbrado = rv_blven.nro_timbrado;
            EXCEPTION
               WHEN no_data_found THEN
                  NULL;
            END;
         END IF;
         EXIT WHEN c_ope_cambios%NOTFOUND;
      END LOOP;
      close c_ope_cambios;
   IF v_borrado <> 0 THEN
         DELETE cb_lib_ventas_tmp
          WHERE cod_persona = p_cod_persona
        AND reversado = 'N'
            AND (fecha = p_fecha OR p_fecha is null)
            AND (hora = p_hora or p_hora is null)
            AND (cod_usuario = p_cod_usuario or p_cod_usuario is null);
   END IF;
    -- LIMPIAR la salida
    DBMS_APPLICATION_INFO.SET_ACTION(NULL);
    DBMS_APPLICATION_INFO.SET_CLIENT_INFO(NULL); 
exception
   when others then
      -- LIMPIAR la salida
      DBMS_APPLICATION_INFO.SET_ACTION(NULL);
      DBMS_APPLICATION_INFO.SET_CLIENT_INFO(NULL); 
      raise_application_error(-20033,v_lugar||sqlerrm);
END;
 ----------------------------------------------------------------
  /* Función que obtiene la secuencia anterior */
  /* Ajustes Jira 2735*/
 ----------------------------------------------------------------
 FUNCTION FU_OBT_SEC_ANTERIOR(p_fecha in date,
                              p_hora in varchar2,
                              p_cod_usuario in varchar2,
                              p_nro_secuencia in number)
 return number is
 v_nro_secuencia   ge_movimientos.nro_secuencia%type;
 begin
    select nvl(max(b.nro_secuencia), 0)
      into v_nro_secuencia
      from ge_movimientos b
     where b.fecha = p_fecha
       and b.hora = p_hora
       and b.cod_usuario = p_cod_usuario
       and b.nro_secuencia < p_nro_secuencia
       and b.cod_tra_padre <> 309;
   return nvl(v_nro_secuencia,0);
 exception
   when no_data_found then
     return 0;
   when others then
   return p_nro_secuencia - 1;
 end;

/* Insertar detalle del Libro Venta */
PROCEDURE PR_INS_LIB_VEN_TMP
 (RP_BLVDT IN CB_LIB_VENTAS_DET_TMP%ROWTYPE
 )
 IS
 v_cantidad number;
begin
   select nvl(count(*),0)
     into v_cantidad
     from cb_lib_ventas_det
    where fecha =  rp_blvdt.fecha
      and hora =  rp_blvdt.hora
      and cod_usuario =  rp_blvdt.cod_usuario
      and nro_secuencia = rp_blvdt.nro_secuencia
      and rownum = 1;
   if v_cantidad = 0 then

     insert into cb_lib_ventas_det_tmp(
        cod_persona, fecha, hora, cod_usuario, nro_secuencia,
        tip_comprobante, tip_venta,
        cod_ofi_origen, cod_mod_padre, cod_mad_padre, cod_tra_padre,
        nro_documento, descripcion,
        cod_moneda, mto_exento, mto_exento_gs, mto_gravado_5,
        mto_gra_5_gs, mto_gravado_10, mto_gra_10_gs, impuesto_5,
        impuesto_5_gs, impuesto_10, impuesto_10_gs, cotizacion,
        reversado, nom_completo, nro_doc_persona,
        nro_cuenta,nro_factura,nro_timbrado,error,aju_impuesto_5,aju_impuesto_10,can_cuota,
        cod_modulo,cod_modalidad,cod_transaccion, cod_tra_base, fec_fac_referencia)
     values(
        rp_blvdt.cod_persona, rp_blvdt.fecha, rp_blvdt.hora, rp_blvdt.cod_usuario,  rp_blvdt.nro_secuencia,
        rp_blvdt.tip_comprobante, rp_blvdt.tip_venta,
        rp_blvdt.cod_ofi_origen, rp_blvdt.cod_mod_padre, rp_blvdt.cod_mad_padre, rp_blvdt.cod_tra_padre,
        rp_blvdt.nro_documento, rp_blvdt.descripcion,
        rp_blvdt.cod_moneda, rp_blvdt.mto_exento, rp_blvdt.mto_exento_gs, rp_blvdt.mto_gravado_5,
        rp_blvdt.mto_gra_5_gs, rp_blvdt.mto_gravado_10, rp_blvdt.mto_gra_10_gs, rp_blvdt.impuesto_5,
        rp_blvdt.impuesto_5_gs, rp_blvdt.impuesto_10, rp_blvdt.impuesto_10_gs, rp_blvdt.cotizacion,
        rp_blvdt.reversado,rp_blvdt.nom_completo,rp_blvdt.nro_doc_persona, rp_blvdt.nro_cuenta,
        rp_blvdt.nro_factura,rp_blvdt.nro_timbrado, rp_blvdt.error, rp_blvdt.aju_impuesto_5, rp_blvdt.aju_impuesto_10,
        rp_blvdt.can_cuota,
        rp_blvdt.cod_modulo,rp_blvdt.cod_modalidad,rp_blvdt.cod_transaccion,rp_blvdt.cod_tra_base,
        rp_blvdt.fec_fac_referencia);
   end if;
end;
/* Genera el libro de ventas temporal. */
PROCEDURE PR_GEN_LIB_VTA_TMP
 (P_COD_PERSONA IN VARCHAR2 DEFAULT NULL
 ,P_FECHA IN DATE DEFAULT NULL
 ,P_HORA IN VARCHAR2 DEFAULT NULL
 ,P_COD_USUARIO IN VARCHAR2 DEFAULT NULL
 ,P_NRO_SECUENCIA IN NUMBER DEFAULT NULL
 )
 IS
  --- Variables
  v_diferencia      number(18) := 0;
  v_cod_persona     varchar2(20);
  v_nro_doc_persona varchar2(30);
  v_nom_completo    varchar2(200);
  v_inserta         varchar2(1);
  v_ins_aux         varchar2(1);
  v_tip_venta       cb_lib_ventas_det_tmp.tip_venta%type;
  rg_lib_ventas     cb_lib_ventas_det_tmp%rowtype;
  v_cod_gru_transaccion ge_gru_transacciones.cod_gru_transaccion%type;
  v_cotizacion      ge_cotizaciones.val_conversion%type;
  v_cod_mon_local   ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_local;
  v_mto_gs          ge_movimientos.monto%type;
  v_tot_iva_gs      ge_movimientos.monto%type;
  v_monto_gs        number(18);
  v_tot_gra_gs      number;
  v_mto_gra_10_gs   number;
  v_mto_gra_5_gs    number;
  v_mto_iva_gs      number;
  v_tot_aju_iva     number;
  v_ok              varchar2(1);
  v_existe          number;
  v_iva_desembolso  number := 0;
  v_tasa            number := 0;
  v_redondeo        NUMBER(2)    := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',null,null, v_cod_mon_local);
  v_cod_tasa        ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('COD_TAS_LIB_VENTAS',null,null,null);
  v_red_mon_local   NUMBER(2)    := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',null,null, v_cod_mon_local);
  v_nro_secuencia   ge_movimientos.nro_secuencia%type;
  v_mar_tolerancia  number(1);
  v_pre_canje       varchar2(1)    := 'N'; --CRO-JM-01/2015: DYDMR-1412: Es un indicador que sirve para saber si corresponde al modulo PRESTAMOS y modalidad CANJES
  v_cod_transaccion ge_movimientos.cod_transaccion%type := '760'; -- CRO-JM-03/2015: DYDMR-1656: con este código de transaccion buscamos en ge_movimientos.-
  v_nro_cuenta      ge_movimientos.nro_cuenta%type;
  v_nro_cuenta_2    ge_movimientos.nro_cuenta%type;
  v_fec_actual      ge_movimientos.fecha%type := pag_cal.fu_obt_fec_actual(1);
  v_lugar           varchar2(2000);
  v_fec_reg         ge_movimientos.fecha%type;
  v_hor_reg         ge_movimientos.hora%type;
  v_usu_reg         ge_movimientos.cod_usuario%type;
  v_cta_reg         varchar2(100);
  v_tra_pad_nro_sec varchar2(2000) := trim(fug_obt_pardinamico('TRA_PAD_NRO_SEC_DOC')); -- DYDMR-4423 NAF Ago/2016
  v_tra_car_interes ge_par_dinamicos.val_parametro%type;
  v_fecha               date;
  v_cod_mod_che_rog      ge_par_dinamicos.val_parametro%type;
  --------------------Parametros nuevos para calculo IVA Che roga Pora--------------------------------
  v_iva_por_int  number;
  v_mensaje      varchar2(100);
  v_contador     number;
v_mod_che_rog ge_par_dinamicos.val_parametro%type;
  --DYDMR-6544 - 16/10/2017
  v_cod_tra_factura ge_transacciones.cod_transaccion%type;
  --- Cursor Principal de movimientos con iva
  cursor principal is
  -- movimientos normales o reversados
  select m.fecha, m.hora, m.cod_usuario,  m.nro_secuencia, m.fec_valor,
         m.cod_modulo, m.cod_modalidad, m.cod_transaccion, m.cod_moneda,
         decode(cod_usu_reversion,null,m.monto,m.monto*-1) monto,
         decode(m.mto_equ_local,0,null,decode(cod_usu_reversion,null,m.mto_equ_local,m.mto_equ_local*-1)) mto_equ_local, m.concepto,
         m.val_tasa,
         m.cod_usu_reversion, m.hor_reversion, m.nro_cuenta, m.referencia,
         m.cod_mod_padre, m.cod_mad_padre, m.nro_documento2, decode(cod_usu_reversion,null,'N','S') reversado,
         m.cod_oficina, m.cod_tra_padre, m.nro_documento, decode(m.cotizacion,0,null,m.cotizacion) cotizacion,
         m.cod_persona, m.nro_documento3, 'N' exenta -- DYDMR-4984 NAF 03/2017
    from ge_movimientos m
   where pab_iva.fu_mov_con_iva(m.cod_modulo, m.cod_modalidad, m.cod_transaccion, m.tip_mov_rubro, m.cod_rubro) = 'S'
     and m.estado = 'N'
     and m.fecha = nvl(p_fecha,m.fecha)
     and m.hora  = nvl(p_hora,m.hora)
     and m.cod_usuario = nvl(p_cod_usuario,m.cod_usuario)
     and m.nro_secuencia = nvl(p_nro_secuencia,m.nro_secuencia)
     and m.monto <> 0
     and m.val_tasa is not null
     and nvl(m.cod_transaccion,0) not in (4050,4052)
     and not exists (select 1 from ge_movimientos x
                              where x.fecha = m.fecha
                                and x.hora   = m.hora
                                and x.cod_usuario = m.cod_usuario
                                and x.estado IN ('X','J','P') and x.reversado = 'N')
         -- Controla que el movimiento no esté facturado.
     and not exists (select 1 from cb_lib_ventas_det d
                                    where d.fecha = m.fecha
                                      and d.hora = m.hora
                                      and d.cod_usuario = m.cod_usuario
                                      and d.nro_cuenta = (case when m.cod_modulo = 7 and m.cod_modalidad = 74 then
                                                                  NVL((select a.nro_cuenta
                                                                        from ge_movimientos a
                                                                       where a.fecha           = M.fecha
                                                                         and a.hora            = M.hora
                                                                         and a.cod_usuario     = M.cod_usuario
                                                                         and a.cod_modulo      = M.cod_modulo
                                                                         --and a.cod_modalidad   = M.cod_modalidad --  SC 19639
                                                                         and a.cod_transaccion = v_cod_transaccion),NULL)
                                                          else
                                                              m.nro_cuenta
                                                          end) -- CRO-JM-03/2015: DYDMR-1656
                                      and d.cod_mod_Padre = m.cod_mod_padre
                                      and d.cod_mad_padre = m.cod_mad_padre
                                      and d.cod_tra_padre = m.cod_tra_padre)
  UNION
   -- generacion de facturas exentas.
   SELECT m.fecha,
          m.hora,
          m.cod_usuario,
          m.nro_secuencia,
          m.fec_valor,
          m.cod_modulo,
          m.cod_modalidad,
          m.cod_transaccion,
          m.cod_moneda,
          decode(cod_usu_reversion, NULL, m.monto, m.monto * -1) monto,
          decode(m.mto_equ_local, 0, NULL,
                 decode(cod_usu_reversion, NULL, m.mto_equ_local, m.mto_equ_local * -1)) mto_equ_local,
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
          nvl(m.cod_persona,p.cod_persona) cod_persona, -- DYDMR-4855 NAF 03/2017
          m.nro_documento3,
          decode(m.cod_modalidad,74,'N','S') exenta -- DYDMR-4984 NAF 03/2017
     FROM ge_movimientos m
          -- DYDMR-4855 NAF 03/2017 recupera cod_persona para poder evaluar tasa personalizada correctamente
          left join ge_cta_clientes p on p.nro_cuenta=m.nro_cuenta and
               p.relacion='P' and rownum=1
    WHERE pab_iva.fu_mov_con_iva(m.cod_modulo, m.cod_modalidad, m.cod_transaccion,m.tip_mov_rubro, m.cod_rubro) = 'N'
      AND m.estado = 'N'
      AND m.fecha = nvl(p_fecha, m.fecha)
      AND m.hora = nvl(p_hora, m.hora)
      AND m.cod_usuario = nvl(p_cod_usuario, m.cod_usuario)
      AND m.nro_secuencia = nvl(p_nro_secuencia, m.nro_secuencia)
      AND (case when (m.cod_modulo = 7 and m.cod_modalidad = 74) then
                          case when (fug_obt_val_personalizada(m.cod_modulo, --verificamos si posee tasa personalizada
                                                               m.cod_modalidad,
                                                               m.cod_oficina,
                                                               m.nro_cuenta,
                                                               m.cod_moneda,
                                                               m.monto,
                                                               'N',
                                                               323,
                                                               null,
                                                               v_fec_actual,
                                                               nvl(m.cod_persona,p.cod_persona)) = 0) then
                                     'S'
                          else
                                     (select ge.exo_impuestos
                                        from ge_clientes ge
                                      where ge.cod_persona = nvl(m.cod_persona,p.cod_persona))
                          end
                else
                  'S'
                end) = 'S' --CRO-JM-01/2015: DYDMR-1412
      AND m.monto != 0
      AND m.val_tasa IS NOT NULL
      AND nvl(m.cod_transaccion, 0) NOT IN (4050, 4052)
      AND NOT EXISTS (SELECT 1
             FROM ge_movimientos x
            WHERE x.fecha = m.fecha
              AND x.hora = m.hora
              AND x.cod_usuario = m.cod_usuario
              AND x.estado IN ('X', 'J', 'P')
              AND x.reversado = 'N')
      --Verifica si la transaccion tiene asociado el I.V.A.
      AND EXISTS (select 1
                    from ge_transacciones_det gd
                   where gd.cod_transaccion = m.cod_transaccion
                     and pab_iva.fu_mov_con_iva(gd.cod_mod_hijo, gd.cod_mad_hijo, gd.cod_tra_hijo,null, null) = 'S')
      --Controla que el cliente tenga exonerado los cargos de I.V.A.
      AND EXISTS (select 1 from ge_tas_fechas gtf
                   where gtf.cod_persona = nvl(m.cod_persona,p.cod_persona)
                     and gtf.val_extension = 100
                     and instr(','||v_cod_tasa||',' ,  ','||gtf.cod_tasa||',') > 0)
      -- Controla que el movimiento no esté facturado.
      AND NOT EXISTS (SELECT 1
             FROM cb_lib_ventas_det d
            WHERE d.fecha = m.fecha
              AND d.hora = m.hora
              AND d.cod_usuario = m.cod_usuario
              AND d.nro_cuenta = (case when m.cod_modulo = 7 and m.cod_modalidad = 74 then
                                      NVL((select a.nro_cuenta
                                            from ge_movimientos a
                                           where a.fecha           = M.fecha
                                             and a.hora            = M.hora
                                             and a.cod_usuario     = M.cod_usuario
                                             and a.cod_modulo      = M.cod_modulo
                                             --and a.cod_modalidad   = M.cod_modalidad -- SC 19639
                                             and a.cod_transaccion = v_cod_transaccion),NULL)
                                  else
                                      m.nro_cuenta
                                   end) -- CRO-JM-03/2015: DYDMR-1656
              AND d.cod_mod_padre = m.cod_mod_padre
              AND d.cod_mad_padre = m.cod_mad_padre
              AND d.cod_tra_padre = m.cod_tra_padre)
   UNION
   --Genera las notas de créditos por cancelación anticipada de préstamos.
   select m.fecha, m.hora, m.cod_usuario,  m.nro_secuencia, m.fec_valor,
         m.cod_modulo, m.cod_modalidad, m.cod_transaccion, m.cod_moneda,
         decode(cod_usu_reversion,null,m.monto,m.monto*-1) monto,
         decode(m.mto_equ_local,0,null,decode(cod_usu_reversion,null,m.mto_equ_local,m.mto_equ_local*-1)) mto_equ_local, m.concepto,
         m.val_tasa,
         m.cod_usu_reversion, m.hor_reversion, m.nro_cuenta, m.referencia,
         m.cod_mod_padre, m.cod_mad_padre, m.nro_documento2, decode(cod_usu_reversion,null,'N','S') reversado,
         m.cod_oficina, m.cod_tra_padre, m.nro_documento, decode(m.cotizacion,0,null,m.cotizacion) cotizacion,
         m.cod_persona, m.nro_documento3, 'N' exenta -- DYDMR-4984 NAF 03/2017
    from ge_movimientos m
   where pab_iva.fu_mov_con_iva(m.cod_modulo, m.cod_modalidad, m.cod_transaccion, m.tip_mov_rubro, m.cod_rubro) = 'N'
     and m.estado = 'N'
     and m.monto <> 0
     and m.val_tasa is not null
     and m.cod_tra_padre in (359,362,360)
     and nvl(m.cod_transaccion,0) in (1708, 2517) --DYDMR-1496 IVA transaccion 2517 - SC 12223
     and not exists (select 1 from ge_movimientos x
                              where x.fecha = m.fecha
                                and x.hora   = m.hora
                                and x.cod_usuario = m.cod_usuario
                                and x.estado IN ('X','J','P') and x.reversado = 'N')
         -- Controla que el movimiento no esté facturado.
     and not exists (select 1 from cb_lib_ventas_det d
                                    where d.fecha = m.fecha
                                      and d.hora = m.hora
                                      and d.cod_usuario = m.cod_usuario
                                      and d.nro_cuenta = (case when m.cod_modulo = 7 and m.cod_modalidad = 74 then
                                                              NVL((select a.nro_cuenta
                                                                        from ge_movimientos a
                                                                       where a.fecha           = M.fecha
                                                                         and a.hora            = M.hora
                                                                         and a.cod_usuario     = M.cod_usuario
                                                                         and a.cod_modulo      = M.cod_modulo
                                                                         --and a.cod_modalidad   = M.cod_modalidad -- SC 19639
                                                                         and a.cod_transaccion = v_cod_transaccion),NULL)
                                                          else
                                                              m.nro_cuenta
                                                          end) -- CRO-JM-03/2015: DYDMR-1656
                                      and d.cod_mod_Padre = m.cod_mod_padre
                                      and d.cod_mad_padre = m.cod_mad_padre
                                      and d.cod_tra_padre = m.cod_tra_padre)
    UNION                                  
   ---Se agrega para el exento de Che Roga
    SELECT m.fecha,
          m.hora,
          m.cod_usuario,
          m.nro_secuencia,
          m.fec_valor,
          m.cod_modulo,
          m.cod_modalidad,
          m.cod_transaccion,
          m.cod_moneda,
          decode(cod_usu_reversion, NULL, m.monto, m.monto * -1) monto,
          decode(m.mto_equ_local, 0, NULL,
                 decode(cod_usu_reversion, NULL, m.mto_equ_local, m.mto_equ_local * -1)) mto_equ_local,
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
          nvl(m.cod_persona,p.cod_persona) cod_persona, -- DYDMR-4855 NAF 03/2017
          m.nro_documento3,
          nvl(fug_obt_pardinamico('COD_MOD_CHE_ROGA', 6, m.cod_modalidad),'N') exenta
         -- decode(m.cod_modalidad,668,'S','N')   -- DYDMR-4984 NAF 03/2017
     FROM ge_movimientos m
          -- DYDMR-4855 NAF 03/2017 recupera cod_persona para poder evaluar tasa personalizada correctamente
          left join ge_cta_clientes p on p.nro_cuenta=m.nro_cuenta and
               p.relacion='P' and rownum=1
    WHERE pab_iva.fu_mov_con_iva(m.cod_modulo, m.cod_modalidad, m.cod_transaccion,m.tip_mov_rubro, m.cod_rubro) = 'N'
      AND m.estado = 'N'
      AND m.cod_mad_padre = 668
      AND m.fecha = nvl(p_fecha, m.fecha)
      AND m.hora = nvl(p_hora, m.hora)
      AND m.cod_usuario = nvl(p_cod_usuario, m.cod_usuario)
      AND m.nro_secuencia = nvl(p_nro_secuencia, m.nro_secuencia)      
      AND m.monto != 0
      AND m.val_tasa IS NOT NULL
      AND nvl(m.cod_transaccion, 0) NOT IN (
        SELECT nvl(to_number(val_parametro), -1)
        FROM ge_par_dinamicos
        WHERE parametro = 'EXC_TRA_CHE_ROG_EXENTO'
        AND cod_modulo = m.cod_modulo
        AND cod_modalidad = m.cod_modalidad
      )
      AND NOT EXISTS (SELECT 1
             FROM ge_movimientos x
            WHERE x.fecha = m.fecha
              AND x.hora = m.hora
              AND x.cod_usuario = m.cod_usuario
              AND x.estado IN ('X', 'J', 'P')
              AND x.reversado = 'N')
      -- Controla que el movimiento no esté facturado.
      AND NOT EXISTS (SELECT 1
             FROM cb_lib_ventas_det d
            WHERE d.fecha = m.fecha
              AND d.hora = m.hora
              AND d.cod_usuario = m.cod_usuario
              AND d.nro_cuenta = (case when m.cod_modulo = 7 and m.cod_modalidad = 74 then
                                      NVL((select a.nro_cuenta
                                            from ge_movimientos a
                                           where a.fecha           = M.fecha
                                             and a.hora            = M.hora
                                             and a.cod_usuario     = M.cod_usuario
                                             and a.cod_modulo      = M.cod_modulo
                                             --and a.cod_modalidad   = M.cod_modalidad -- SC 19639
                                             and a.cod_transaccion = v_cod_transaccion),NULL)
                                  else
                                      m.nro_cuenta
                                   end) -- CRO-JM-03/2015: DYDMR-1656
              AND d.cod_mod_padre = m.cod_mod_padre
              AND d.cod_mad_padre = m.cod_mad_padre
              AND d.cod_tra_padre = m.cod_tra_padre)                                   
   order by fecha, hora, cod_usuario, nro_secuencia;

   TYPE cursor1_type IS TABLE OF principal%ROWTYPE;
   reg cursor1_type;

  --- Cursor Secundario de movimimientos
  cursor secundario(p_fecha in date, p_cod_usuario in varchar2, p_hora in varchar2, p_nro_secuencia in number, p_cod_modulo in number, p_cod_modalidad in number, p_exenta in varchar2) is
   select m.nro_secuencia, m.cod_modulo, m.cod_modalidad, m.cod_transaccion, m.cod_moneda,
          decode(cod_usu_reversion,null,m.monto,m.monto*-1) monto,
          decode(m.mto_equ_local,0,null,decode(cod_usu_reversion,null,m.mto_equ_local,m.mto_equ_local*-1)) mto_equ_local,
          m.concepto, m.val_tasa, m.nro_cuenta, m.referencia, m.tip_mov_rubro, m.cod_rubro,
          decode(m.cotizacion,0,null,m.cotizacion) cotizacion,m.fecha,m.hora,m.cod_usuario
    from ge_movimientos m
   where fecha = p_fecha
     and cod_usuario = p_cod_usuario
     and hora = p_hora
     and m.cod_tra_padre not in (900) -- devengado
     and nro_secuencia < p_nro_secuencia --CRO-JM-01/2015: DYDMR-1412
     and nro_secuencia > (case when (m.cod_modulo = 7 and m.cod_modalidad = 74) then        --CRO-JM-01/2015: DYDMR-1412
                            p_nro_secuencia-2
                          else
                            -9999
                          end)
     and p_exenta='N'
   union
   /* 28/06/2010 : Iva generado sobre saldo de interes de cuotas vencidas monto imponible=NRO_DOCUMENTO2 */
   select m.nro_secuencia, m.cod_modulo, m.cod_modalidad, m.cod_transaccion, m.cod_moneda,
          /* 25/02/2014 PN DI: Se comenta y se calcula el monto teniendo en cuenta los decimales, debido a diferencias grandes por decimales,
             ya que el monto calculado que se encuentra comentado no consideraba los decimales porque nro_documento2 no guarda con decimales*/
          --decode(cod_usu_reversion,null,m.nro_documento2,m.nro_documento2*-1) monto,
          decode(cod_usu_reversion,null,nvl(round(m.NRO_DOCUMENTO3/nvl(m.COTIZACION,1), nvl(fug_obt_redondeo_seg(m.cod_moneda),2)),m.NRO_DOCUMENTO2),
                                        nvl(round(m.NRO_DOCUMENTO3/nvl(m.COTIZACION,1), nvl(fug_obt_redondeo_seg(m.cod_moneda),2))*-1,m.nro_documento2*-1)) monto,
          decode(m.mto_equ_local,0,null,decode(cod_usu_reversion,null,m.nro_documento3,m.nro_documento3*-1)) mto_equ_local,
          m.concepto, m.val_tasa, m.nro_cuenta, m.referencia, m.tip_mov_rubro, m.cod_rubro,
          decode(m.cotizacion,0,null,m.cotizacion) cotizacion,m.fecha,m.hora,m.cod_usuario
    from ge_movimientos m
   where fecha = p_fecha
     and cod_usuario = p_cod_usuario
     and hora = p_hora
     and nro_secuencia = p_nro_secuencia
     and (cod_modulo =6 and cod_tra_padre = 391 and cod_Transaccion=710)
     and p_exenta='N'
   union
    -- DYDMR-4984 NAF 03/2017 Soporte de Persona con IVA Exento / Cargo IVA incluido (recupera el mismo registro que el principal)
    select m.nro_secuencia, m.cod_modulo, m.cod_modalidad, m.cod_transaccion, m.cod_moneda,
          decode(cod_usu_reversion,null,m.monto,m.monto*-1) monto,
          decode(m.mto_equ_local,0,null,decode(cod_usu_reversion,null,m.mto_equ_local,m.mto_equ_local*-1)) mto_equ_local,
          m.concepto, m.val_tasa, m.nro_cuenta, m.referencia, m.tip_mov_rubro, m.cod_rubro,
          decode(m.cotizacion,0,null,m.cotizacion) cotizacion,m.fecha,m.hora,m.cod_usuario
    from ge_movimientos m
   where fecha = p_fecha
     and cod_usuario = p_cod_usuario
     and hora = p_hora
     and nro_secuencia = p_nro_secuencia
     and p_exenta='S'
   order by FECHA, HORA, COD_USUARIO, NRO_SECUENCIA desc;


  --------------------------------------------------------------
  -- Función que verifica si corresponde insertar la reversión -
  --------------------------------------------------------------
  /******Ajuste JIRA 2735******
  Se agregó número de secuencia como parámetro para que se borre sólo los registros reversados by PS*/

  function fp_ins_reversion(p_fecha date,
                            p_hora  varchar2,
                            p_cod_usuario varchar2,
                            p_nro_secuencia varchar2) return varchar2 is
    v_existe  number := 0;
    v_inserta varchar2(1);
    begin
     -- Busca si existe entre los movimientos temporales.
     begin
       select nvl(count(*),0)
         into v_existe
         from cb_lib_ventas_det_tmp dt
        where dt.fecha = p_fecha
          and dt.hora  = p_hora
          and dt.cod_usuario = p_cod_usuario
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
          where vd.fecha = p_fecha
            and vd.hora  = p_hora
            and vd.cod_usuario = p_cod_usuario
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
       --BBVASOP-1514-Se inserta en observaciónes antes del borrado
       pab_iva.pr_ins_observaciones(p_fecha, p_hora, p_cod_usuario, 'S');
       begin
         delete cb_lib_ventas_det_tmp dt
          where dt.fecha = p_fecha
            and dt.hora  = p_hora
            and dt.cod_usuario = p_cod_usuario
            and dt.nro_secuencia = p_nro_secuencia;
       exception
         when others then
           raise_application_error(-20000,'Error al Elminar Registros. CB_LIB_VENTAS_DET_TMP '||sqlerrm);
       end;
       v_inserta := 'N';
     end if;
     return v_inserta;
  end fp_ins_reversion;
  ---------------------------------------------
  -- Función para obtener el tipo de Factura...
  ---------------------------------------------
  function f_obt_tipo (p_cod_modulo in number,
                       p_cod_modalidad in number,
                       p_cod_transaccion in number,
                       p_cod_tra_padre in number
                       ) return varchar2 is
     v_tip_factura varchar2(2);
     v_tip_persona varchar2(1);
  begin
     --desembolso se considera credito, Iva generado s/cuotas vencidas prestamo,
     if p_cod_tra_padre in (/*358,*/ 391, 7503)  then -- Iva generado s/cuotas vencidas prestamo
        v_tip_factura := 'CR';
     else
       --
       Select 'CR' into v_tip_factura
         from ge_gru_transacciones_det
        where cod_gru_transaccion = v_cod_gru_transaccion
          and cod_modulo = p_cod_modulo
          and cod_modalidad = p_cod_modalidad
          and cod_transaccion = p_cod_tra_padre;
     end if;

     -- Verificamos si es una operacion de Repo Otorgado --
     If FUM_OBT_OPE_REPO(p_cod_modulo,p_cod_modalidad,'S','O') = 'S' Then
        -- Indicador Tipo de Persona: P-Bancos del País, B-BCP, C-Clientes. --
        select o.tip_persona
          into v_tip_persona
          from md_tip_operaciones o
         where o.cod_mad_operacion = p_cod_modalidad;
         -- CNFREINT-104 --
         if v_tip_persona in ('P','B') then  -- Tipo Financiero
            v_tip_factura := 'CR';
         elsif v_tip_persona in ('C') then -- Tipo No Financiero
            v_tip_factura := 'CO';
         end if;
     end if;

     return v_tip_factura;
  exception
     When NO_DATA_FOUND then
          v_tip_factura := 'CO';
          return v_tip_factura;
     When TOO_MANY_ROWS then
          v_tip_factura := 'CR';
          return v_tip_factura;
  end f_obt_tipo;
  --------------------------------------------------------
  -- Función para obtener la descripción de la transacción
  --------------------------------------------------------
  function f_obt_des_transaccion(p_cod_modulo in number,
                                 p_cod_modalidad in number,
                                 p_cod_transaccion in number) return varchar2 is
    v_descripcion ge_transacciones.descripcion%type;
    
  begin

    select descripcion
      into v_descripcion
      from ge_transacciones
     where cod_modulo = p_cod_modulo
       and cod_modalidad = p_cod_modalidad
       and cod_transaccion = p_cod_transaccion;

    return v_descripcion;
  exception
     when others then
       return null;
  end f_obt_des_transaccion;

BEGIN
  v_lugar:= 'Inicio';
  DBMS_APPLICATION_INFO.SET_CLIENT_INFO('PR_GEN_LIB_VTA_TMP, Iniciando');
  pab_iva.pr_act_equ_local(p_fecha, p_hora, p_cod_usuario);
  v_cod_gru_transaccion := fug_obt_pardinamico('GRU_FAC_CREDITO', 6, 65, null, null);
  v_tra_car_interes     := fug_obt_pardinamico('COD_TRA_CAR_INTERES');
                   
  v_contador := 0;
  -- Movimientos Principales.
  v_lugar:= 'Antes del cursor principal';
  OPEN principal;
     LOOP
        FETCH principal BULK COLLECT
           INTO reg LIMIT 30000;
        FOR i IN 1 .. reg.count LOOP
  --for m in principal loop * Se cambia para utilizar el método del Bulk Collect * RM --
    /*30/07/2010: Verificar si es Cobro/Cancelacion de cuota de prestamo,
    si la cuota venció en mes anterior al actual no generar factura,
    la factura ya fue generada en el cierre del mes de vencimiento de la cuota.
    */ 
     v_cod_mod_che_rog:= nvl(fug_obt_pardinamico('COD_MOD_CHE_ROGA', 6, reg(i).cod_modalidad),'N'); 
    v_iva_por_int         := to_number(nvl(fug_obt_pardinamico('PRE_CHE_ROG_POR_IVA_CAL', 6, reg(i).cod_modalidad, null, null, null),'1')); 
        -- Monitoreo del avance cada 10000 registros 
        IF MOD(i, 10000) = 0 OR i = reg.COUNT THEN
            v_contador := v_contador + 1;            
            v_mensaje := v_contador||' - PR_GEN_LIB_VTA_TMP-registro ' || i || ' de ' || reg.COUNT;
            DBMS_APPLICATION_INFO.SET_CLIENT_INFO(v_mensaje);
        END IF;
   if (reg(i).cod_modulo = 7 and reg(i).cod_modalidad = 74) then --CRO-JM-01/2015: DYDMR-1412
       v_pre_canje := 'S';
    else
       v_pre_canje := 'N';
    end if;

     v_existe  := 0;
     v_fec_reg  := reg(i).fecha;
     v_hor_reg  := reg(i).hora;
     v_usu_reg  := reg(i).cod_usuario;
     v_cta_reg  := reg(i).cod_modulo||'-'||reg(i).cod_modalidad||'-'||reg(i).nro_cuenta;     

  -- Obt. la fec.habil para prever vto.cuota en fecha no habil
      Select count(*) into v_existe
        from pr_cuotas
       where nro_cuenta = reg(i).nro_cuenta
         and nro_cuota  = reg(i).nro_documento3
         and pag_cal.fu_obt_fec_habil(fec_vencimiento,null,reg(i).cod_oficina) < pag_cal.Fu_obt_fec_pri_dia_mes_habil(6)
         and reg(i).cod_modulo = 6
         and reg(i).cod_Tra_padre in(360,359,362,364)
         and reg(i).cod_transaccion = 708 --iva s/interes vencido
         and rownum = 1;

      v_lugar:= 'Antes de verificar reversión.';
  if v_existe <> 0 then --no debe hacer nada
     null;
  else
    if nvl(reg(i).reversado,'N') = 'N' then
    -- Si No está reversado Inserta.
      v_inserta := 'S';
   -- elsif nvl(m.reversado,'N') = 'S' then
   elsif nvl(reg(i).reversado,'N') = 'S' then
    /****Ajustes JIIRA 2735 - 27/12/2012****/
   /* Debe tener encuenta el nro de secuencia, cuando posee un sólo registro, y cuando posee varios, debe obtener la secuencia anterior*/
      if reg(i).cod_tra_padre = 366 and reg(i).cod_transaccion = 1631 then
         v_lugar := 'Al obtener la secuencia anterior Tp-366';
         v_nro_secuencia := reg(i).nro_secuencia;
         v_ins_aux := null;
         v_ins_aux := fp_ins_reversion(reg(i).fec_valor,reg(i).hor_reversion,reg(i).cod_usu_reversion,v_nro_secuencia);
         if nvl(v_ins_aux,'N') = 'N' then
            v_nro_secuencia := FU_OBT_SEC_ANTERIOR( reg(i).fecha,reg(i).hora,reg(i).cod_usuario,reg(i).nro_secuencia);
         end if;
      elsif reg(i).cod_tra_padre = 370 and reg(i).cod_transaccion = 1631 then
           v_lugar := 'Al obtener la secuencia anterior Tp-370';
           v_nro_secuencia := FU_OBT_SEC_ANTERIOR( reg(i).fecha,reg(i).hora,reg(i).cod_usuario,reg(i).nro_secuencia); 
         v_ins_aux := null;
         v_ins_aux := fp_ins_reversion(reg(i).fec_valor,reg(i).hor_reversion,reg(i).cod_usu_reversion,v_nro_secuencia); 
         if nvl(v_ins_aux,'N') = 'N' then
            v_nro_secuencia := reg(i).nro_secuencia; 
         end if;    
      elsif INSTR(','||v_tra_pad_nro_sec||',',','||reg(i).cod_tra_padre||',') > 0 then -- DYDMR-4423 NAF Ago/2016
         v_nro_secuencia := reg(i).nro_secuencia;
      else
         v_lugar := 'Al obtener la secuencia anterior';
         v_nro_secuencia := FU_OBT_SEC_ANTERIOR( reg(i).fecha,reg(i).hora,reg(i).cod_usuario,reg(i).nro_secuencia);
      end if;
     -- Si es una reversión del histórico verifica si corresponde insertar.
     v_lugar:= 'Verifica rev. histórica.';
     
    --Se verifica si la cuenta corresponde a GP para utilizar la fecha correspondiente
    --Para GP la fecha definida es la columna fecha,para los demas casos utilizar fec_valor
      if reg(i).cod_modulo=5 
      and (fut_obt_procesadora(reg(i).nro_cuenta)= FUG_OBT_PARDINAMICO('COD_ENT_GLOBAL')
      or fut_obt_procesadora(reg(i).nro_cuenta)= FUG_OBT_PARDINAMICO('COD_PRO_')) 
            then
              begin
                select m.FECHA 
                  into v_fecha
                  from gv_movimientos m
                  where m.FEC_VALOR = reg(i).fec_valor
                  and m.HORA = reg(i).hor_reversion
                  and m.COD_USUARIO = reg(i).cod_usu_reversion
                  and m.NRO_SECUENCIA = v_nro_secuencia;
                exception
                  when others then
                    v_fecha:=reg(i).fecha;
                end;
            else
              v_fecha:=reg(i).fec_valor;
            end if;
            -------------
     v_inserta := fp_ins_reversion(v_fecha,reg(i).hor_reversion,reg(i).cod_usu_reversion,v_nro_secuencia);
    end if;
    if v_inserta = 'S' then
       v_lugar:= 'Rev. histórica.';
      -- NG 07/07/2010. Modificado para tomar la cotizacion de GE_MOVIMIENTOS y no la de GE_COTIZACIONES.
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
      -- Busca los datos de la persona.
      v_lugar:= 'Obtiene datos persona.';
      pab_iva.pr_obt_dat_persona(reg(i).cod_mod_padre,reg(i).cod_mad_padre,reg(i).cod_usuario,reg(i).fecha, reg(i).hora, reg(i).nro_secuencia,reg(i).nro_cuenta,
                           reg(i).nro_documento2, reg(i).referencia,reg(i).cod_moneda,reg(i).monto,reg(i).val_tasa,
                           v_cod_persona, v_nro_doc_persona, v_nom_completo);

      -- Para tarjetas: modifica margen de diferencia entre iva calculado e iva del movimiento
      if reg(i).cod_modulo = 5 then
         v_mar_tolerancia := 5;
      else
         v_mar_tolerancia := 2; -- margen original
      end if;

      -- Si el parametro de persona es nulo inserta todos si no por persona.
      if p_cod_persona is null or p_cod_persona = nvl(v_cod_persona,'x') then
        -- Movimientos con Cargos.
        --Limpia el registro.
        rg_lib_ventas := null;
        -- DYDMR-4984 NAF 03/2017 Soporte de Persona con IVA Exento / Cargo IVA incluido
        if reg(i).exenta = 'N' then
          if reg(i).cod_moneda = v_cod_mon_local then
              v_monto_gs := nvl(reg(i).monto,0);
          else
              v_monto_gs := nvl(reg(i).mto_equ_local,round(v_cotizacion * reg(i).monto));
          end if;
        else
          v_monto_gs := 0; -- IVA exenta es monto cero
        end if;
        for b in secundario(reg(i).fecha, reg(i).cod_usuario, reg(i).hora, reg(i).nro_secuencia, reg(i).cod_modulo, reg(i).cod_modalidad, reg(i).exenta) loop
          --DYDMR-6544 - 16/10/2017 --------------------
          if b.cod_modulo = 6 and b.cod_transaccion = 1632 then
             v_cod_tra_factura := 1520;
          elsif b.cod_modulo = 6 and b.cod_transaccion = 1633 then
             v_cod_tra_factura := 1521;
          else
             v_cod_tra_factura := b.cod_transaccion;
          end if;
          -- limpiar variable
          v_iva_desembolso := 0;

          v_lugar:= 'Obtener Mov Cargo.';
          if pab_iva.fu_mov_cargo(b.cod_modulo, b.cod_modalidad, b.cod_transaccion, b.tip_mov_rubro, b.cod_rubro)  = 'S'
        and (reg(i).nro_cuenta = b.nro_cuenta or reg(i).nro_cuenta is null or b.nro_cuenta is null)
         /*and (m.cod_tra_padre != '359' or (m.cod_tra_padre != '362' and m.cod_transaccion != '1708'))*/ /*Ajuste JIRA 2735*/ then
             --verificar si es préstamos. VC 01-10-2010
             --si no cobró iva sobre interés en el desembolso significa que es cuotizado y debe generar, sino no porque ya cobró al desembolsar
             if b.cod_modulo = 6 and b.cod_transaccion in (802,817,825,828) then --transacción de interés
               Select count(*)
                 into v_iva_desembolso
                 from pr_sol_cargos a, pr_cta_prestamos c
                where a.nro_solicitud = c.nro_solicitud
                  and c.nro_cuenta = b.nro_cuenta
                  and a.cod_Transaccion = 709;
             end if;
            --si no cobró en desembolso significa que es cuotizado y debe generar factura por el iva en el interés
            if v_iva_desembolso <= 0 then

              if v_cod_mon_local <> reg(i).cod_moneda then
                v_redondeo := nvl(fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',6,NULL,reg(i).cod_moneda),0);
              else
                v_redondeo := 0;
              end if;

              v_lugar:= 'Obtener Tip Venta1.';
              v_tip_venta := f_obt_tipo (b.cod_modulo,
                                         b.cod_modalidad,
                                         b.cod_transaccion,
                                         reg(i).cod_tra_padre);
              --Limpia el registro.
              rg_lib_ventas := null;
              -- Calcula el impuesto del movimiento actual.

              -- Carga con ceros los montos.
              rg_lib_ventas.impuesto_10_gs := 0;
              rg_lib_ventas.mto_gra_10_gs  := 0;
              --
              rg_lib_ventas.mto_gravado_10 := 0;
              rg_lib_ventas.impuesto_10    := 0;
              --
              rg_lib_ventas.impuesto_5_gs  := 0;
              rg_lib_ventas.mto_gra_5_gs   := 0;
              --
              rg_lib_ventas.mto_gravado_5  := 0;
              rg_lib_ventas.impuesto_5     := 0;
              --
              rg_lib_ventas.mto_exento_gs  := 0;
              rg_lib_ventas.mto_exento     := 0;
              --
              rg_lib_ventas.aju_impuesto_10 := 0;
              rg_lib_ventas.aju_impuesto_5  := 0;
              --
              v_mto_gs := NVL(b.mto_equ_local,round(nvl(b.monto,0)*v_cotizacion,0));
              v_tasa := round((reg(i).monto*100)/b.monto);
              --
              if reg(i).val_tasa = 10 and reg(i).exenta = 'N' then -- DYDMR-2833 NAF 03/2017
                 rg_lib_ventas.mto_gravado_10 := nvl(b.monto,0);
                 rg_lib_ventas.mto_gra_10_gs  := v_mto_gs;
                 rg_lib_ventas.impuesto_10    := round(nvl(b.monto,0)*reg(i).val_tasa/100,v_redondeo);
                 rg_lib_ventas.impuesto_10_gs := round(rg_lib_ventas.impuesto_10*v_cotizacion);
                ----------------------------------------------------------
                if v_cod_mon_local <> reg(i).cod_moneda then
                  v_mto_iva_gs := round(rg_lib_ventas.mto_gra_10_gs * reg(i).val_tasa / 100);
                  if v_mto_iva_gs - rg_lib_ventas.impuesto_10_gs between 6 and 50 then
                    rg_lib_ventas.aju_impuesto_10 := v_mto_iva_gs - rg_lib_ventas.impuesto_10_gs;
                    rg_lib_ventas.impuesto_10_gs := v_mto_iva_gs;
                  end if;
                end if;
                -- Verifica si el movimiento ya fue ajustado por el proceso prg_act_dif_iva
                -- si ya fue ajustado utiliza el importe ajustado del movimiento.
                if reg(i).cod_moneda <> v_cod_mon_local and reg(i).mto_equ_local <> round((reg(i).monto * reg(i).cotizacion),v_red_mon_local)then
                    -- if v_pre_canje <> 'S' then --CRO-JM-03/2015: DYDMR-1656
                    rg_lib_ventas.impuesto_10_gs := reg(i).mto_equ_local;
               --end if;
                end if;
                --
                --24/11/2010: Tener en cuenta que en ciertos movimientos que afectan tarjetas
                --se reciben ivas que no corresponden a 5% 0 10%, grabar el iva tal cual
                --se recibe.
                v_lugar:= 'Obtener Afecta1.';
                If FU_OBT_AFECTA(b.cod_modulo,b.cod_modalidad,
                                 b.cod_transaccion) = 'J'
                and reg(i).val_tasa <> v_tasa then
                    rg_lib_ventas.impuesto_10  := reg(i).monto;
                    rg_lib_ventas.impuesto_10_gs := round(rg_lib_ventas.impuesto_10*v_cotizacion);
                    --
                    if v_cod_mon_local <> reg(i).cod_moneda then
                      v_mto_iva_gs := rg_lib_ventas.impuesto_10_gs;
                    end if;
                End if;
                --
                /** Ajustes **/
                --Afecta (G) Seg.en Cuotas
                if reg(i).cod_transaccion = 1631 then -- impuesto por seguro
                   --Se obtiene el total (gravada + iva)
                   if reg(i).cod_tra_padre = 366 then
                     v_lugar:= 'Obtener Seguro incendio.';
                     BEGIN
                      select abs(monto), abs(round(monto * v_cotizacion))
                        into rg_lib_ventas.impuesto_10, rg_lib_ventas.impuesto_10_gs
                        from ge_movimientos
                       where nro_cuenta = reg(i).referencia
                         and nro_documento3 = reg(i).nro_documento3
                         and cod_tra_padre IN (359, 360,362,364)
                         and cod_transaccion  = 1520
                         --and reversado = 'N';
                         and reversado = reg(i).reversado;
                         EXCEPTION
                           WHEN NO_DATA_FOUND THEN
                             rg_lib_ventas.impuesto_10 := 0;
                             rg_lib_ventas.impuesto_10_gs := 0;
                      END;

                   --elsif reg(i).cod_tra_padre = 370 then
                   elsif reg(i).cod_tra_padre in (358,359,360,362,364,370) then
                     v_lugar:= 'Obtener Seguro Vida.';
                    BEGIN
             --Proyecto SDSEGVID-3 Seguro de Vida Distribuido - Agregado tran. 358--
                       select abs(monto), abs(round(monto * v_cotizacion))
                         into rg_lib_ventas.impuesto_10, rg_lib_ventas.impuesto_10_gs
                         from ge_movimientos
                        where nro_cuenta = reg(i).referencia
                          and nro_documento3 = reg(i).nro_documento3
                          and cod_tra_padre IN (358,359,360,362,364)
                          and cod_transaccion = 1521
                          --and reversado = 'N';
                          and reversado = reg(i).reversado;
                          EXCEPTION
                             WHEN NO_DATA_FOUND THEN
                             rg_lib_ventas.impuesto_10 := 0;
                             rg_lib_ventas.impuesto_10_gs := 0;
                      END;

                   end if;
                   --Obtener la gravada.
                   rg_lib_ventas.mto_gravado_10 := rg_lib_ventas.impuesto_10    - reg(i).monto;
                   rg_lib_ventas.mto_gra_10_gs  := rg_lib_ventas.impuesto_10_gs - (reg(i).monto * v_cotizacion);
                   --Seteo el Iva
                   rg_lib_ventas.impuesto_10    := reg(i).monto;
                   rg_lib_ventas.impuesto_10_gs := (reg(i).monto * v_cotizacion);
                end if;
              elsif reg(i).val_tasa = 5 and reg(i).exenta = 'N' and instr(fug_obt_pardinamico('PRE_TRA_EXE_CHE_ROGA'), b.cod_transaccion) = 0 then -- DYDMR-2833 NAF 03/2017
                IF b.cod_modulo = 6 and v_cod_mod_che_rog = 'S' THEN
                    rg_lib_ventas.mto_gravado_5 := round(((nvl(b.monto,0)) * v_iva_por_int /100), v_redondeo)  ;
                    rg_lib_ventas.mto_gra_5_gs  := rg_lib_ventas.mto_gravado_5 * v_cotizacion;
                    rg_lib_ventas.impuesto_5    := round(nvl(rg_lib_ventas.mto_gravado_5,0) * reg(i).val_tasa / 100, v_redondeo);
                    rg_lib_ventas.impuesto_5_gs := round(rg_lib_ventas.impuesto_5 * v_cotizacion);
                ELSE  
                    rg_lib_ventas.mto_gravado_5 := nvl(b.monto,0);
                    rg_lib_ventas.mto_gra_5_gs  := v_mto_gs;
                    rg_lib_ventas.impuesto_5    := round(nvl(b.monto,0) * reg(i).val_tasa / 100, v_redondeo);
                    rg_lib_ventas.impuesto_5_gs := round(rg_lib_ventas.impuesto_5 * v_cotizacion);
                END IF;    
                ----------------------------------------------------------
                if v_cod_mon_local <> reg(i).cod_moneda then
                   v_mto_iva_gs := round(rg_lib_ventas.mto_gra_5_gs * reg(i).val_tasa / 100);
                   if v_mto_iva_gs - rg_lib_ventas.impuesto_5_gs between 6 and 50 then
                      rg_lib_ventas.aju_impuesto_5 := v_mto_iva_gs - rg_lib_ventas.impuesto_5_gs;
                      rg_lib_ventas.impuesto_5_gs := v_mto_iva_gs;
                   end if;
                end if;
                -- Verifica si el movimiento ya fue ajustado por el proceso prg_act_dif_iva
                -- si ya fue ajustado utiliza el importe ajustado del movimiento.
                if reg(i).cod_moneda <> v_cod_mon_local and reg(i).mto_equ_local <> round((reg(i).monto * reg(i).cotizacion),v_red_mon_local)then
                   rg_lib_ventas.impuesto_5_gs := reg(i).mto_equ_local;
                end if;
                --
                --
                --24/11/2010: Tener en cuenta que en ciertos movimientos que afectan tarjetas
                --se reciben ivas que no corresponden a 5% 0 10%, grabar el iva tal cual
                --se recibe.
                v_lugar:= 'Obtener Afecta2.';
                If FU_OBT_AFECTA(b.cod_modulo,b.cod_modalidad,
                                 b.cod_transaccion) = 'J'
                and reg(i).val_tasa <> v_tasa then
                    rg_lib_ventas.impuesto_5  := reg(i).monto;
                    rg_lib_ventas.impuesto_5_gs := round(rg_lib_ventas.impuesto_5*v_cotizacion);
                    --
                    if v_cod_mon_local <> reg(i).cod_moneda then
                       v_mto_iva_gs := rg_lib_ventas.impuesto_5_gs;
                    end if;
                End if;
                --
              else
                rg_lib_ventas.mto_exento_gs := v_mto_gs;
                rg_lib_ventas.mto_exento    := nvl(b.monto,0);
              end if;
              -- para verificar sumatoria
              v_tot_iva_gs := nvl(v_tot_iva_gs,0) + nvl(rg_lib_ventas.impuesto_10_gs,0) +
                                                    nvl(rg_lib_ventas.impuesto_5_gs,0);
              v_tot_gra_gs := nvl(v_tot_gra_gs,0) + nvl(rg_lib_ventas.mto_gra_10_gs,0) +
                                                    nvl(rg_lib_ventas.mto_gra_5_gs,0);
              v_tot_aju_iva := nvl(v_tot_aju_iva,0) + nvl(rg_lib_ventas.aju_impuesto_5,0) +
                                                      nvl(rg_lib_ventas.aju_impuesto_10,0);
              --
              rg_lib_ventas.cod_persona    := v_cod_persona;
              rg_lib_ventas.nro_doc_persona:= v_nro_doc_persona;
              rg_lib_ventas.nom_completo   := v_nom_completo;
              rg_lib_ventas.cod_ofi_origen := reg(i).cod_oficina;
              rg_lib_ventas.cod_mod_padre  := reg(i).cod_mod_padre;
              rg_lib_ventas.cod_mad_padre  := reg(i).cod_mad_padre;
              rg_lib_ventas.cod_tra_padre  := reg(i).cod_tra_padre;
              rg_lib_ventas.nro_documento  := reg(i).nro_documento;
              rg_lib_ventas.reversado      := reg(i).reversado;
              rg_lib_ventas.fecha          := reg(i).fecha;
              rg_lib_ventas.hora           := reg(i).hora;
              rg_lib_ventas.cod_usuario    := reg(i).cod_usuario;
              ---
              if reg(i).cod_Tra_padre = 2510 then -- Retrocesiones
                begin
                   select nvl(a.nro_factura,0),
                          nvl(a.nro_timbrado,0),
                          cod_transaccion
                     into rg_lib_ventas.nro_factura,
                          rg_lib_ventas.nro_timbrado,
                          reg(i).cod_transaccion
                     from ge_ret_com_intereses_det a
                    where a.nro_devolucion  = reg(i).nro_documento
                      and a.nro_linea       = reg(i).nro_documento2
                      and a.cod_transaccion <> reg(i).cod_transaccion;
                exception
                   when others then
                      rg_lib_ventas.nro_factura  := 0;
                      rg_lib_ventas.nro_timbrado := 0;
                end;
                if instr(','||fug_obt_pardinamico('COD_TRA_RET_CDA',
                      reg(i).cod_modulo, reg(i).cod_modalidad,
                      reg(i).cod_moneda, reg(i).cod_oficina, null)||',',
                      reg(i).cod_transaccion) > 0 then
                   null;
                else
                   if reg(i).reversado = 'S' then
                      rg_lib_ventas.reversado := 'N';
                   else
                      rg_lib_ventas.reversado := 'S';
                   end if;
                end if;
                /*
                || DYDMR-2277
                || ITGF - Error Proceso 62 - Generacion de Archivo Hechauka
                */
                if rg_lib_ventas.cod_persona is null then
                   begin
                      select a.cod_persona
                        into rg_lib_ventas.cod_persona
                        from ge_ret_com_intereses a
                       where a.nro_devolucion  = reg(i).nro_documento;
                   exception
                      when others then
                         rg_lib_ventas.cod_persona := null;
                   end;
                end if;
                if rg_lib_ventas.cod_persona is not null then
                   if rg_lib_ventas.nom_completo is null then
                      begin
                         rg_lib_ventas.nom_completo := fue_obt_nom_persona(
                                                       rg_lib_ventas.cod_persona);
                      exception
                         when others then
                            rg_lib_ventas.nom_completo := null;
                      end;
                   end if;
                   if rg_lib_ventas.nro_doc_persona is null then
                      begin
                         rg_lib_ventas.nro_doc_persona := fue_obt_nro_doc_persona(
                                                          rg_lib_ventas.cod_persona);
                      exception
                         when others then
                            rg_lib_ventas.nro_documento := null;
                      end;
                   end if;
                end if;
              -- Si el movimiento es reversado carga el número de Factura original
              elsif reg(i).reversado = 'S' then
                v_lugar := 'Obtener Nro Factura Rev1.';
                begin
                  select ld.nro_factura, ld.nro_timbrado, ld.fecha
                    into rg_lib_ventas.nro_factura, rg_lib_ventas.nro_timbrado, rg_lib_ventas.fec_fac_referencia
                    from cb_lib_ventas_det ld
                   where ld.fecha = reg(i).fec_valor
                     and ld.hora = reg(i).hor_reversion
                     and ld.cod_usuario = reg(i).cod_usu_reversion
                     and ld.nro_secuencia = b.nro_secuencia;
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
              --Asigno el valor de reversado para que genere la nota de credito
              if reg(i).reversado = 'N' and reg(i).cod_tra_padre in ('359','362','360') and
                 reg(i).cod_transaccion in (1708, 2517) then --DYDMR-1496 IVA transaccion 2517 - SC 12223
                 rg_lib_ventas.reversado := 'S';

                 -- DYDMR-5875 NAF 08/2017
                 -- en caso de cancelacion anticipada de prestamos se busca factura del desembolso
                 if reg(i).cod_modulo = 6 and reg(i).cod_tra_padre in ('359','360','362') and reg(i).cod_transaccion in (1708, 2517) then
                    begin
                       select d.nro_factura, d.nro_timbrado, d.fecha
                        into rg_lib_ventas.nro_factura, rg_lib_ventas.nro_timbrado, rg_lib_ventas.fec_fac_referencia
                       from pr_cta_prestamos p, pr_movimientos_his m, cb_lib_ventas_det d
                       where m.nro_cuenta = p.nro_cuenta
		         and m.nro_cuenta = d.nro_cuenta
                         and p.fec_inicio = m.fec_valor
                         and d.fecha = m.fecha and d.hora = m.hora
                         and d.nro_secuencia = m.nro_secuencia
			 and d.cod_usuario = m.cod_usuario
                         and m.cod_tra_padre = 358
                         and m.cod_modulo = 6 and m.cod_transaccion IN (719,709)
                         and p.nro_cuenta = reg(i).nro_cuenta
                         and d.nro_factura is not null;
                    exception
                       when others then
                          rg_lib_ventas.nro_factura  := 0;
                          rg_lib_ventas.nro_timbrado := 0;
                    end;
                    --Proyecto SDDEC312NC-1 / Nota Crédito varias Facturas------
                    if ((rg_lib_ventas.nro_factura = '0') and
                        (instr(nvl(v_tra_car_interes, '0'), ','||v_cod_tra_factura||',') > 0)) then
                        begin
                           select d.nro_factura, d.nro_timbrado, d.fecha
                            into rg_lib_ventas.nro_factura, rg_lib_ventas.nro_timbrado, rg_lib_ventas.fec_fac_referencia
                           from cb_lib_ventas_det d, cb_lib_ventas e
                           where d.nro_factura = e.nro_factura
                             and d.nro_timbrado = e.nro_timbrado
                             and e.tip_comprobante = 'F' --Factura--
                             and d.cod_tra_padre = 391 --CARGO IVA S/INTERES VENCIDO
                             and d.cod_mod_padre = 6
                             and d.cod_mad_padre = reg(i).cod_modalidad
                             and d.cod_transaccion = 710 --IVA S/ INTERES - INGRESO AL FISCO SOBRE CUTOA VENCIDA
                             and d.nro_cuenta = reg(i).nro_cuenta
                             and d.nro_factura is not null
                             and d.impuesto_10 = reg(i).monto;
                        exception
                           when others then
                              rg_lib_ventas.nro_factura  := 0;
                              rg_lib_ventas.nro_timbrado := 0;
                        end;
                    end if;
                 end if;
              end if;
              --
              ----------------------------------------------
              rg_lib_ventas.nro_secuencia  := b.nro_secuencia;
              rg_lib_ventas.tip_venta      := v_tip_venta;
              rg_lib_ventas.descripcion    := substr(f_obt_des_transaccion(b.cod_modulo,b.cod_modalidad,v_cod_tra_factura),1,35);
              rg_lib_ventas.cod_tra_base   := v_cod_tra_factura;
              rg_lib_ventas.cod_moneda     := b.cod_moneda;
              rg_lib_ventas.cotizacion     := v_cotizacion;

              v_lugar := 'Obtener nro_cuenta pre_canje1';
              if v_pre_canje = 'S' and pab_iva.fu_mov_cargo(b.cod_modulo,b.cod_modalidad,b.cod_transaccion) = 'N' then  -- CRO-JM-03/2015: DYDMR-1656
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
              rg_lib_ventas.nro_cuenta     := b.nro_cuenta;
              end if;
              --
              /*23/11/2010: Si la transaccion corresponde a movimientos
              que afectan saldo de tarjeta (mov.que vienen en archivos de la procesadora)
              y el impoorte grabado es negativo corresponde a reversiones realizadas
              por la procesadora entonces corresponde generar nota de credito, para estos
              casos se graba en cb_lib_ventas_det_tmp con indicador reversado para que
              el cierre genere nota de credito. */
              --
              v_lugar:= 'Obtener afecta3';
              If fu_obt_afecta(b.cod_modulo,
                              b.cod_modalidad,
                              b.cod_transaccion) = 'J' --Afecta Saldo de Tarjeta
              and reg(i).reversado = 'N'
              and reg(i).monto < 0 then
                 rg_lib_ventas.reversado   := 'S';
                 rg_lib_ventas.impuesto_10_gs := rg_lib_ventas.impuesto_10_gs*-1;
                 rg_lib_ventas.mto_gra_10_gs  := rg_lib_ventas.mto_gra_10_gs*-1;
                 rg_lib_ventas.mto_gravado_10 := rg_lib_ventas.mto_gravado_10*-1;
                 rg_lib_ventas.impuesto_10    := rg_lib_ventas.impuesto_10*-1;
                 rg_lib_ventas.impuesto_5_gs  := rg_lib_ventas.impuesto_5_gs*-1;
                 rg_lib_ventas.mto_gra_5_gs   := rg_lib_ventas.mto_gra_5_gs*-1;
                 rg_lib_ventas.mto_gravado_5  := rg_lib_ventas.mto_gravado_5*-1;
                 rg_lib_ventas.impuesto_5     := rg_lib_ventas.impuesto_5*-1;
                 rg_lib_ventas.mto_exento_gs  := rg_lib_ventas.mto_exento_gs*-1;
                 rg_lib_ventas.mto_exento     := rg_lib_ventas.mto_exento*-1;
                 rg_lib_ventas.aju_impuesto_10 := rg_lib_ventas.aju_impuesto_10*-1;
                 rg_lib_ventas.aju_impuesto_5  := rg_lib_ventas.aju_impuesto_5*-1;
              End if;
              --
              /*Para Hechauka 3.0 - Definir cuotas. CNF 16/03/15*/
              v_lugar:= 'Definir Cuotas-Hechauka1';
              if reg(i).cod_transaccion = 709 and rg_lib_ventas.cod_tra_padre = 358
                 --DYDMR-1851 ITGF ERROR 08/05/15 - SC 16035
                 and /*rg_lib_ventas.cod_mod_padre = 6*/ reg(i).cod_modulo = 6 then
                 select p.can_cuotas
                   into rg_lib_ventas.can_cuota
                   from pr_cta_prestamos p
                  where p.nro_cuenta = reg(i).nro_cuenta;
              elsif reg(i).cod_transaccion = 710 then
                 rg_lib_ventas.can_cuota := 1;
              else
                 rg_lib_ventas.can_cuota := 0;
              end if;
              --Para cod_modulo,cod_modalidad,cod_transaccion
              -- DYDMR-4984 NAF 03/2017 Soporte de Persona con IVA Exento / Cargo IVA incluido
              if reg(i).exenta = 'N' then
                 rg_lib_ventas.cod_modulo :=reg(i).cod_modulo;
                 rg_lib_ventas.cod_modalidad :=reg(i).cod_modalidad;
                 rg_lib_ventas.cod_transaccion :=reg(i).cod_transaccion;
              else
                 rg_lib_ventas.cod_modulo :=null;
                 rg_lib_ventas.cod_modalidad :=null;
                 rg_lib_ventas.cod_transaccion :=null;
              end if;
        --
              begin
                v_lugar:= 'Inserta Libro Vta tmp1';
                pab_iva.pr_ins_lib_ven_tmp(rg_lib_ventas);
              exception
                when dup_val_on_index then
                  --Si existe en entre los temporales limpia las variables.
                  v_tot_iva_gs    := v_monto_gs; -- esto es para no generar movimientos
                  v_tot_gra_gs    := 0;
                  rg_lib_ventas := null;
                when others then
                 it_mail.mail(fug_obt_dir_correo,
                 fug_obt_pardinamico('IVA_ENV_COR_ERRORES'),
                 'Error al insertar datos en Libro Venta Temporal.',
                 'Se ha encontrado un error al intentar insertar datos en el Libro Venta Temporal. A continuación los datos de la mensajería: ' ||
                 chr(10) || 'Nro. Factura : ' ||
                 rg_lib_ventas.nro_factura || chr(10) ||
                 'Nro. Cuenta: ' ||
                 reg(i).nro_cuenta || chr(10) ||
                 'Fecha: ' ||
                 to_char(rg_lib_ventas.fecha, 'DD/MM/YYYY') || chr(10) ||
                 'Hora: ' ||
                 rg_lib_ventas.hora || chr(10) ||
                 'Monto: ' ||
                 TRIM(to_char(reg(i).monto, '999,999,999,999,999.99')) ||
                 chr(10) || chr(10) || 'Atentamente.');
                 raise_application_error(-20000,'Error al insertar datos en Libro Venta Temporal '||sqlerrm);
              end;
              /*30/06/2010: Verificar si el movimiento corresponde a iva s/interes de cuota de prestamo
              vencido dentro del mes, debe marcar con X el tipo de comprobante del registro que ya fue
              generado en el cierre de fecha correspondiente al vencimiento de la cuota
              */
              --If nvl(m.reversado,'N') = 'N' then
                v_lugar := 'Actualiza Lib Venta Tmp';
                Update cb_lib_ventas_det_tmp
                   set tip_comprobante = decode(reg(i).reversado,'S',null,'X')
                 where nro_cuenta = reg(i).nro_cuenta
                   and nro_documento = reg(i).nro_documento3
                   and cod_tra_padre = 391  --Tran.Padre Iva s/Interes vencido
                   and reg(i).cod_modulo=6
                   and reg(i).cod_Tra_padre in(360,359,362,364)
                   and reg(i).cod_transaccion = 708; --iva s/interes vencido
              --End if;
            end if; --si era iva cuotizado
          end if;

          --if v_pre_canje <> 'S' then -- CRO-JM-12/01/2015: DYDMR-1412
             v_lugar := 'Verifica si sale del cursor secundario.';
          exit when (pab_iva.fu_mov_con_iva(b.cod_modulo, b.cod_modalidad, b.cod_transaccion, b.tip_mov_rubro, b.cod_rubro) = 'S') or
                    ((abs(nvl(v_monto_gs,0)-nvl(v_tot_iva_gs,0)) < nvl(v_mar_tolerancia,2) ));
          --end if;

        end loop;

          -- DYDMR-4984 NAF 03/2017 Soporte de Persona con IVA Exento / Cargo IVA incluido
          if reg(i).exenta = 'N' then
            --Controla si hay diferencia.
            if reg(i).cod_moneda = v_cod_mon_local then
                v_monto_gs := nvl(reg(i).monto,0);
            else
                v_monto_gs := nvl(reg(i).mto_equ_local,round(v_cotizacion * reg(i).monto));
            end if;
          else
            v_monto_gs := 0; -- IVA exenta es monto cero
          end if;
          if nvl(v_tot_iva_gs,0) <> nvl(v_monto_gs,0) then
            rg_lib_ventas.error := null;
            if ((nvl(v_monto_gs,0)-nvl(v_tot_iva_gs,0) > 5 and reg(i).cod_moneda = v_cod_mon_local) or
                (nvl(v_monto_gs,0)-nvl(v_tot_iva_gs,0) > 50 and reg(i).cod_moneda <> v_cod_mon_local)) and
               (reg(i).cod_mad_padre not in (628,640)/* and m.cod_transaccion not in (4050,4052)*/)
          /*and v_pre_canje <> 'S'*/ then
                -- estas modalidades se ajustan solas -- PREST.LARGO PLAZO Y AFD
                -- tambien los movimientos de devolucion de IVA se consideran NOTA DE CREDITO DIRECTO
                -- Si hay diferencia mayor a 2 gs da un error.
                rg_lib_ventas.error := substr('Dif. en el IVA para el Movimiento: Mov.IVA: '||
                                              v_monto_gs||' Cal.IVA: '||v_tot_iva_gs,1,300);
            end if;
          --Si hay diferencia modifica la tabla temporal.
            v_diferencia := nvl(v_tot_iva_gs,0) - nvl(v_monto_gs,0) - nvl(v_tot_aju_iva,0);
            if reg(i).val_tasa = 10 then
              if abs(rg_lib_ventas.aju_impuesto_10 + v_diferencia) between 6 and 50 then
                rg_lib_ventas.aju_impuesto_10 := rg_lib_ventas.aju_impuesto_10 + v_diferencia;
              end if;
            else
              if abs(rg_lib_ventas.aju_impuesto_5 + v_diferencia) between 6 and 50 then
                rg_lib_ventas.aju_impuesto_5 := rg_lib_ventas.aju_impuesto_5 + v_diferencia;
              end if;
            end if;
            --
            begin
              if v_diferencia <> 0 then
                v_lugar := 'Actualiza Lib Venta Tmp por Dif';
                update cb_lib_ventas_det_tmp dt
                   set dt.error = nvl(dt.error,rg_lib_ventas.error),
                       dt.aju_impuesto_5  = rg_lib_ventas.aju_impuesto_5,
                       dt.aju_impuesto_10 = rg_lib_ventas.aju_impuesto_10
                 where dt.fecha = rg_lib_ventas.fecha
                   and dt.hora  = rg_lib_ventas.hora
                   and dt.cod_usuario   = rg_lib_ventas.cod_usuario
                   and dt.nro_secuencia = rg_lib_ventas.nro_secuencia;
                IF SQL%NOTFOUND THEN
                   raise no_data_found;
                end if;
              end if;
            exception
              when no_data_found then
                   -- Obtiene el tipo valor del redondeo
                   if v_cod_mon_local != reg(i).cod_moneda then
                      v_redondeo := nvl(fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',NULL,NULL,reg(i).cod_moneda),0);
                   else
                      v_redondeo := 0;
                   end if;
                   -- se inserta el regisgro de ajuste solo para las modalidades de AFP y PCP LARGO PLAZO
                    v_lugar := 'Obtener Tip Venta2.';
                    v_tip_venta := f_obt_tipo (reg(i).cod_modulo,
                                               reg(i).cod_modalidad,
                                               reg(i).cod_transaccion,
                                               reg(i).cod_tra_padre);
                    --Limpia el registro.
                    rg_lib_ventas := null;
                    -- Calcula el impuesto del movimiento actual.
                    -- Carga con ceros los montos.
                    rg_lib_ventas.impuesto_10_gs := 0;
                    rg_lib_ventas.mto_gra_10_gs  := 0;
                    --
                    rg_lib_ventas.mto_gravado_10 := 0;
                    rg_lib_ventas.impuesto_10    := 0;
                    --
                    rg_lib_ventas.impuesto_5_gs  := 0;
                    rg_lib_ventas.mto_gra_5_gs   := 0;
                    --
                    rg_lib_ventas.mto_gravado_5  := 0;
                    rg_lib_ventas.impuesto_5     := 0;
                    --
                    rg_lib_ventas.mto_exento_gs  := 0;
                    rg_lib_ventas.mto_exento     := 0;
                    --
                    v_mto_gs := nvl(reg(i).mto_equ_local,nvl(reg(i).monto,0)*v_cotizacion);
                    --
                    if reg(i).val_tasa = 10 then
                      rg_lib_ventas.mto_gra_10_gs  := round(v_mto_gs*100/reg(i).val_tasa);
                      rg_lib_ventas.impuesto_10_gs := round(v_mto_gs);
                      --
                      rg_lib_ventas.mto_gravado_10 := round(reg(i).monto*100/reg(i).val_tasa);
                      rg_lib_ventas.impuesto_10    := round(reg(i).monto,v_redondeo);
                    elsif reg(i).val_tasa = 5 then
                      rg_lib_ventas.mto_gra_5_gs  := round(v_mto_gs*100/reg(i).val_tasa);
                      rg_lib_ventas.impuesto_5_gs := round(v_mto_gs);
                      --
                      rg_lib_ventas.mto_gravado_5 := round(reg(i).monto*100/reg(i).val_tasa);
                      rg_lib_ventas.impuesto_5    := round(reg(i).monto,v_redondeo);
                    else
                      rg_lib_ventas.mto_exento_gs := round(v_mto_gs);
                      rg_lib_ventas.mto_exento    := round(nvl(reg(i).monto,0),v_redondeo);
                    end if;
                    --
                    rg_lib_ventas.cod_persona    := v_cod_persona;
                    rg_lib_ventas.nro_doc_persona:= v_nro_doc_persona;
                    rg_lib_ventas.nom_completo   := v_nom_completo;
                    rg_lib_ventas.cod_ofi_origen := reg(i).cod_oficina;
                    rg_lib_ventas.cod_mod_padre  := reg(i).cod_mod_padre;
                    rg_lib_ventas.cod_mad_padre  := reg(i).cod_mad_padre;
                    rg_lib_ventas.cod_tra_padre  := reg(i).cod_tra_padre;
                    rg_lib_ventas.nro_documento  := reg(i).nro_documento;
                    rg_lib_ventas.reversado      := reg(i).reversado;
                    rg_lib_ventas.fecha          := reg(i).fecha;
                    rg_lib_ventas.hora           := reg(i).hora;
                    rg_lib_ventas.cod_usuario    := reg(i).cod_usuario;
                    ---
                    if reg(i).cod_Tra_padre = 2510 then -- Retrocesiones
                      begin
                         select nvl(a.nro_factura,0),
                                nvl(a.nro_timbrado,0),
                                cod_transaccion
                           into rg_lib_ventas.nro_factura,
                                rg_lib_ventas.nro_timbrado,
                                reg(i).cod_transaccion
                           from ge_ret_com_intereses_det a
                          where a.nro_devolucion  = reg(i).nro_documento
                            and a.nro_linea       = reg(i).nro_documento2
                            and a.cod_transaccion <> reg(i).cod_transaccion;
                      exception
                         when others then
                            rg_lib_ventas.nro_factura  := 0;
                            rg_lib_ventas.nro_timbrado := 0;
                      end;
                      if instr(','||fug_obt_pardinamico('COD_TRA_RET_CDA',
                            reg(i).cod_modulo, reg(i).cod_modalidad,
                            reg(i).cod_moneda, reg(i).cod_oficina, null)||',',
                            reg(i).cod_transaccion) > 0 then
                         null;
                      else
                         if reg(i).reversado = 'S' then
                            rg_lib_ventas.reversado := 'N';
                         else
                            rg_lib_ventas.reversado := 'S';
                         end if;
                      end if;
                    -- Si el movimiento es reversado carga el número de Factura original
                    elsif reg(i).reversado = 'S' then
                      v_lugar := 'Obtener Nro Factura Rev2.';
                      begin
                        select ld.nro_factura, ld.nro_timbrado, ld.fecha
                          into rg_lib_ventas.nro_factura, rg_lib_ventas.nro_timbrado, rg_lib_ventas.fec_fac_referencia
                          from cb_lib_ventas_det ld
                         where ld.fecha = reg(i).fec_valor
                           and ld.hora = reg(i).hor_reversion
                           and ld.cod_usuario = reg(i).cod_usu_reversion
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
                    --Asigno el valor de reversado para que genere la nota de credito
                    if reg(i).reversado = 'N' and reg(i).cod_tra_padre in ('359','362','360') and
                       reg(i).cod_transaccion in (1708, 2517) then --DYDMR-1496 IVA transaccion 2517 - SC 12223
                       rg_lib_ventas.reversado := 'S';
                    end if;
                    --
                    rg_lib_ventas.nro_secuencia  := reg(i).nro_secuencia;
                    rg_lib_ventas.tip_venta      := v_tip_venta;
                    rg_lib_ventas.descripcion    := substr(f_obt_des_transaccion(reg(i).cod_modulo,reg(i).cod_modalidad,reg(i).cod_transaccion),1,35);
                    rg_lib_ventas.cod_tra_base   := reg(i).cod_transaccion;
                    rg_lib_ventas.cod_moneda     := reg(i).cod_moneda;
                    rg_lib_ventas.cotizacion     := v_cotizacion;
                    v_lugar := 'Obtener nro_cuenta pre_canje2';
                    if v_pre_canje = 'S' then  -- CRO-JM-03/2015: DYDMR-1656
                        begin
                          select a.nro_cuenta
                           into v_nro_cuenta_2
                            from ge_movimientos a
                           where a.fecha           = reg(i).fecha
                             and a.hora            = reg(i).hora
                             and a.cod_usuario     = reg(i).cod_usuario
                             and a.cod_transaccion = v_cod_transaccion;
                        exception
                            when others then
                              v_nro_cuenta_2 := null;
                        end;
                       rg_lib_ventas.nro_cuenta  := v_nro_cuenta_2;
                    else
                       rg_lib_ventas.nro_cuenta     := reg(i).nro_cuenta;
                    end if;
                    --
                    /*23/11/2010: Si la transaccion corresponde a movimientos
                    que afectan saldo de tarjeta (mov.que vienen en archivos de la procesadora)
                    y el impoorte grabado es negativo corresponde a reversiones realizadas
                    por la procesadora entonces corresponde generar nota de credito, para estos
                    casos se graba en cb_lib_ventas_det_tmp con indicador reversado para que
                    el cierre genere nota de credito. */
                    --
                    If fu_obt_afecta(reg(i).cod_modulo,
                                    reg(i).cod_modalidad,
                                    reg(i).cod_transaccion) = 'J' --Afecta Saldo de Tarjeta
                    and reg(i).reversado = 'N'
                    and reg(i).monto < 0 then
                       rg_lib_ventas.reversado   := 'S';
                       rg_lib_ventas.impuesto_10_gs := rg_lib_ventas.impuesto_10_gs*-1;
                       rg_lib_ventas.mto_gra_10_gs  := rg_lib_ventas.mto_gra_10_gs*-1;
                       rg_lib_ventas.mto_gravado_10 := rg_lib_ventas.mto_gravado_10*-1;
                       rg_lib_ventas.impuesto_10    := rg_lib_ventas.impuesto_10*-1;
                       rg_lib_ventas.impuesto_5_gs  := rg_lib_ventas.impuesto_5_gs*-1;
                       rg_lib_ventas.mto_gra_5_gs   := rg_lib_ventas.mto_gra_5_gs*-1;
                       rg_lib_ventas.mto_gravado_5  := rg_lib_ventas.mto_gravado_5*-1;
                       rg_lib_ventas.impuesto_5     := rg_lib_ventas.impuesto_5*-1;
                       rg_lib_ventas.mto_exento_gs  := rg_lib_ventas.mto_exento_gs*-1;
                       rg_lib_ventas.mto_exento     := rg_lib_ventas.mto_exento*-1;
                       rg_lib_ventas.aju_impuesto_10 := rg_lib_ventas.aju_impuesto_10*-1;
                       rg_lib_ventas.aju_impuesto_5  := rg_lib_ventas.aju_impuesto_5*-1;
                    End if;
                    --
          /*Para Hechauka 3.0 - Definir cuotas. CNF 16/03/15*/
                    v_lugar:= 'Definir Cuotas-Hechauka2';
                    if reg(i).cod_transaccion = 709 and rg_lib_ventas.cod_tra_padre = 358
                      --DYDMR-1851 ITGF ERROR 08/05/15 - SC 16035
                       and /*rg_lib_ventas.cod_mod_padre = 6*/ reg(i).cod_modulo = 6 then
                       select p.can_cuotas
                         into rg_lib_ventas.can_cuota
                         from pr_cta_prestamos p
                        where p.nro_cuenta = reg(i).nro_cuenta;
                    elsif reg(i).cod_transaccion = 710 then
                       rg_lib_ventas.can_cuota := 1;
                    else
                       rg_lib_ventas.can_cuota := 0;
                    end if;
                    --
                    begin
                      v_lugar :='Inserta Libro Vta tmp2';
                      pab_iva.pr_ins_lib_ven_tmp(rg_lib_ventas);
                    exception
                      when dup_val_on_index then
                        --Si existe en entre los temporales limpia las variables.
                        v_tot_iva_gs     := 0;
                        rg_lib_ventas := null;
                      when others then
                        it_mail.mail(fug_obt_dir_correo,
                        fug_obt_pardinamico('IVA_ENV_COR_ERRORES'),
                        'Error al insertar datos en Libro Venta Temporal.',
                        'Se ha encontrado un error al intentar insertar datos en el Libro Venta Temporal. A continuación los datos de la mensajería: ' ||
                        chr(10) || 'Nro. Factura : ' ||
                        rg_lib_ventas.nro_factura || chr(10) ||
                        'Nro. Cuenta: ' ||
                        reg(i).nro_cuenta || chr(10) ||
                        'Fecha: ' ||
                        to_char(rg_lib_ventas.fecha, 'DD/MM/YYYY') || chr(10) ||
                        'Hora: ' ||
                        rg_lib_ventas.hora || chr(10) ||
                        'Monto: ' ||
                        TRIM(to_char(reg(i).monto, '999,999,999,999,999.99')) ||
                        chr(10) || chr(10) || 'Atentamente.');
                        raise_application_error(-20000,'Error al insertar datos en Libro Venta Temporal '||sqlerrm);
                    end;

            end;
            ---Ajuste Diferencia --FSOP-22644
            --Verifico que exista aún diferencia en calculo de IVA
            IF nvl(v_tot_iva_gs,0) <> nvl(v_monto_gs,0) THEN
              -- Carga con ceros los montos.
              rg_lib_ventas.impuesto_10_gs := 0;
              rg_lib_ventas.mto_gra_10_gs  := 0;
              --
              rg_lib_ventas.mto_gravado_10 := 0;
              rg_lib_ventas.impuesto_10    := 0;
              --
              rg_lib_ventas.impuesto_5_gs := 0;
              rg_lib_ventas.mto_gra_5_gs  := 0;
              --
              rg_lib_ventas.mto_gravado_5 := 0;
              rg_lib_ventas.impuesto_5    := 0;

              v_mto_gs := nvl(reg(i).mto_equ_local,round(nvl(reg(i).monto, 0) * v_cotizacion, 0));
             
              IF reg(i).val_tasa = 10 THEN
                rg_lib_ventas.mto_gra_10_gs  := (round(11 * v_mto_gs / reg(i).val_tasa) * reg(i).val_tasa) -  v_mto_gs;
                rg_lib_ventas.impuesto_10_gs := v_mto_gs;
                --
                rg_lib_ventas.mto_gravado_10 := (round(11 * reg(i).monto / reg(i).val_tasa) * reg(i).val_tasa) -  reg(i).monto;
                rg_lib_ventas.impuesto_10    := reg(i).monto;
              ELSIF reg(i).val_tasa = 5 THEN
                rg_lib_ventas.mto_gra_5_gs  := round(round(1.05 * v_mto_gs) / 0.05) -  v_mto_gs;
                rg_lib_ventas.impuesto_5_gs := v_mto_gs;
                --
                rg_lib_ventas.mto_gravado_5 := round(round(1.05 * reg(i).monto) / 0.05) -  reg(i).monto;
                rg_lib_ventas.impuesto_5    := reg(i).monto;
              END IF;
              --Actualiza Temporal
              BEGIN
                v_lugar := 'Actualiza Temporal por Dif ';
                update cb_lib_ventas_det_tmp dt
                   set dt.mto_gra_10_gs   = rg_lib_ventas.mto_gra_10_gs,
                       dt.impuesto_10_gs  = rg_lib_ventas.impuesto_10_gs,
                       dt.mto_gravado_10  = rg_lib_ventas.mto_gravado_10,
                       dt.impuesto_10     = rg_lib_ventas.impuesto_10,
                       dt.mto_gra_5_gs    = rg_lib_ventas.mto_gra_5_gs,
                       dt.impuesto_5_gs   = rg_lib_ventas.impuesto_5_gs,
                       dt.mto_gravado_5   = rg_lib_ventas.mto_gravado_5,
                       dt.impuesto_5      = rg_lib_ventas.impuesto_5
                 where dt.fecha         = rg_lib_ventas.fecha
                   and dt.hora          = rg_lib_ventas.hora
                   and dt.cod_usuario   = rg_lib_ventas.cod_usuario
                   and dt.nro_secuencia = rg_lib_ventas.nro_secuencia;
              END;
            END IF;
            ---            
          end if;
      end if;
    end if;
   End if;
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
/* Verifica si un movimiento es de iva o no */
FUNCTION FU_MOV_CON_IVA
 (P_COD_MODULO IN NUMBER
 ,P_COD_MODALIDAD IN NUMBER
 ,P_COD_TRANSACCION IN NUMBER
 ,P_COD_TIP_MOV_RUBRO IN VARCHAR2 := null
 ,P_COD_RUBRO IN VARCHAR2 := null
 )
 RETURN VARCHAR2
 IS
V_SINO VARCHAR2(1) := 'N';
V_RUBROS VARCHAR2(200) := '#240102440100199#240102440100299#240102440101099#240102440102299#';
--06/09/10: Se agregan los rubros asociados a la transaccion 708 (Iva s/Interes vencido)
V_RUB_REVERSION VARCHAR2(200) := '#150102470200499#150102470200599#';
BEGIN
  IF P_COD_TIP_MOV_RUBRO = 'C' AND INSTR(V_RUB_REVERSION, P_COD_RUBRO) > 0 AND P_COD_TRANSACCION IS NULL THEN
    -- reversion de iva
    V_SINO := 'S';
  ELSIF P_COD_TIP_MOV_RUBRO = 'C' AND INSTR(V_RUBROS, P_COD_RUBRO) > 0 THEN
     -- si es un movimiento directo al rubro de iva
     V_SINO := 'S';
  ELSE
   BEGIN
     -- verifico si el asiento de la transaccion lleva a un asiento de credito fiscal
     SELECT 'S'
       INTO V_SINO
       FROM GE_TIP_ASIENTOS B, GE_TRANSACCIONES  A
      WHERE A.COD_MODULO = P_COD_MODULO
        AND A.COD_MODALIDAD = P_COD_MODALIDAD
        AND A.COD_TRANSACCION = P_COD_TRANSACCION
        AND A.BATCH = 'B'
        AND B.COD_TIP_ASIENTO = A.COD_TIP_ASIENTO
        AND B.TIP_MOVIMIENTO = 'C' -- SOL CREDITOS
        AND INSTR(V_RUBROS, B.COD_RUBRO) > 0
        AND ROWNUM = 1;
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         BEGIN
           -- verifico si el asiento de la transaccion lleva a un asiento de credito fiscal
           SELECT 'S'
             INTO V_SINO
             FROM GE_TIP_ASIENTOS B, GE_TRANSACCIONES  A
            WHERE A.COD_MODULO = P_COD_MODULO
              AND A.COD_MODALIDAD = P_COD_MODALIDAD
              AND A.COD_TRANSACCION = P_COD_TRANSACCION
              AND A.BATCH = 'B'
              AND B.COD_TIP_ASIENTO = A.COD_TIP_ASIENTO2
              AND B.TIP_MOVIMIENTO = 'C' -- SOL CREDITOS
              AND INSTR(V_RUBROS, B.COD_RUBRO) > 0
              AND ROWNUM = 1;
         EXCEPTION
            WHEN NO_DATA_FOUND THEN
            --PCC-RET_COM_INT / PCCRECOIN-84: Para que no redondee el monto gravado
                 BEGIN
                    SELECT 'S'
                      INTO V_SINO
                      FROM GE_TIP_ASIENTOS B, GE_TRANSACCIONES  A
                     WHERE A.COD_MODULO = P_COD_MODULO
                       AND A.COD_MODALIDAD = P_COD_MODALIDAD
                       AND A.COD_TRANSACCION = P_COD_TRANSACCION
                       AND A.BATCH = 'B'
                       AND B.COD_TIP_ASIENTO in (A.COD_TIP_ASIENTO,A.COD_TIP_ASIENTO2)
                       AND B.TIP_MOVIMIENTO = 'D'
                       AND INSTR(V_RUBROS, B.COD_RUBRO) > 0
                       AND ROWNUM = 1
                       AND exists (select 1
                                     from ge_transacciones_det d, ge_gru_transacciones_det g
                                    where A.COD_MODULO = d.COD_MODULO
                                      AND A.COD_MODALIDAD = d.COD_MODALIDAD
                                      AND A.COD_TRANSACCION = d.COD_TRA_HIJO
                                      AND g.COD_MODULO = d.COD_MODULO
                                      AND g.COD_MODALIDAD = d.COD_MODALIDAD
                                      AND g.COD_TRANSACCION = d.COD_TRANSACCION
                                      AND g.cod_gru_transaccion IN (82, 83));
                 EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                       V_SINO := 'N';
                 END;
         END;
   END;
  END IF;
  RETURN V_SINO;
END;


/* Verifica si un movimiento es de cargo */
FUNCTION FU_MOV_CARGO
 (P_COD_MODULO IN NUMBER
 ,P_COD_MODALIDAD IN NUMBER
 ,P_COD_TRANSACCION IN NUMBER
 ,P_COD_TIP_MOV_RUBRO IN VARCHAR2 := null
 ,P_COD_RUBRO IN VARCHAR2 := null
 )
 RETURN VARCHAR2
 IS
V_SINO VARCHAR2(1) := 'N';
V_RUBRO VARCHAR2(200) := '14_802259%';
v_cod_mod_che_roga      ge_par_dinamicos.val_parametro%type := nvl(fug_obt_pardinamico('COD_MOD_CHE_ROGA', P_COD_MODULO, P_COD_MODALIDAD),'N');
BEGIN
  IF P_COD_MODALIDAD = 670 AND P_COD_TRANSACCION = 802 THEN
     V_SINO := 'N';
  ELSIF P_COD_TIP_MOV_RUBRO = 'C' AND SUBSTR(P_COD_RUBRO,1,1) = '6' THEN
     -- si es un movimiento directo al rubro de iva
     V_SINO := 'S';
  ELSIF p_cod_modulo = 5 AND (p_cod_transaccion IN (1084, 1085) or (INSTR(fug_obt_pardinamico('TRA_CON_CAR_GP',p_cod_modulo, null, null, null),p_cod_transaccion)>0)) THEN
         -- seguro de vida total (1085) y comisión  de movimientos diarios (1084)
         --GP:en par dinamico TRA_CON_CAR_GP se cargan las transaacciones con cargos referentes a GP
         v_sino := 'S';
  ELSIF P_COD_MODULO = 6 AND P_COD_TRANSACCION IN (802,803,817,825,828) THEN /*Ajuste JIRA 2735*/
     /*FQ - Se borró la transacción 1708 debido a que no corresponde a un cargo - SPI 2818*/
     -- cobro de interes.
     V_SINO := 'S';
  ELSIF P_COD_MODULO = 10 AND P_COD_TRANSACCION IN (817) THEN
     -- cobro de interes
     V_SINO := 'S';
  ELSIF P_COD_MODULO = 6 AND P_COD_TRANSACCION = 710 THEN
     -- 28/06/2010 : cobro de iva s/interes vencido (tra.padre 391)
     V_SINO := 'S';
  --24/11/2010 : Los cargos que afectan saldo de tarjetas se deben facturar
  ELSIF P_COD_MODULO = 5 AND fu_obt_afecta(p_cod_modulo,
                              p_cod_modalidad,
                              p_cod_transaccion) = 'J' then
     V_SINO := 'S';
  --08/09/2015 DYDMR-2289 FM INCIDENCIA DESCUADRE DE IVA --
  ELSIF P_COD_MODULO = 6 AND P_COD_TRANSACCION = 736 THEN
     V_SINO := 'S';
--10/08/2022 INCIDENCIA DESCUADRE DE IVA NUEVA MODALIDAD 703--
  ELSIF P_COD_MODULO = 6 AND P_COD_TRANSACCION = 700 AND P_COD_MODALIDAD = 703  THEN
     V_SINO := 'S';
  ELSIF P_COD_MODULO = 6 AND v_cod_mod_che_roga = 'S' AND instr(fug_obt_pardinamico('PRE_TRA_EXE_CHE_ROGA'), P_COD_TRANSACCION) > 0 THEN   
     V_SINO := 'S';
  ELSE
   BEGIN
     -- verifico si el asiento de la transaccion lleva a un asiento de credito fiscal
     SELECT 'S'
       INTO V_SINO
       FROM GE_TIP_ASIENTOS B, GE_TRANSACCIONES  A
      WHERE A.COD_MODULO = P_COD_MODULO
        AND A.COD_MODALIDAD = P_COD_MODALIDAD
        AND A.COD_TRANSACCION = P_COD_TRANSACCION
        AND A.BATCH = 'B'
        AND NVL(A.AFECTA,'X') NOT IN ('C') --,'A')
        AND B.COD_TIP_ASIENTO = A.COD_TIP_ASIENTO
        AND B.TIP_MOVIMIENTO = 'C' -- SOL CREDITOS
        AND (B.COD_RUBRO LIKE '6%' OR B.COD_RUBRO  LIKE V_RUBRO
            OR substr(B.COD_RUBRO,1,13) IN (SELECT substr(c.cod_rubro,1,13)
                                              FROM cb_gru_rubros_det c
                                             WHERE c.cod_gru_rubro = 8) )
        AND ROWNUM = 1;
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
           BEGIN
             -- verifico si el asiento de la transaccion lleva a un asiento de credito fiscal
             SELECT 'S'
               INTO V_SINO
               FROM GE_TIP_ASIENTOS B, GE_TRANSACCIONES  A
              WHERE A.COD_MODULO = P_COD_MODULO
                AND A.COD_MODALIDAD = P_COD_MODALIDAD
                AND A.COD_TRANSACCION = P_COD_TRANSACCION
                AND A.BATCH = 'B'
                AND NVL(A.AFECTA,'X') NOT IN ('C') --,'A')
                AND B.COD_TIP_ASIENTO = A.COD_TIP_ASIENTO2
                AND B.TIP_MOVIMIENTO = 'C' -- SOL CREDITOS
                AND (B.COD_RUBRO LIKE '6%' OR B.COD_RUBRO  LIKE V_RUBRO)
                AND ROWNUM = 1;
           EXCEPTION
              WHEN NO_DATA_FOUND THEN
                 -- PCC-RET_COM_INT / PCCRECOIN-84: Para que no redondee el monto gravado
                 BEGIN
                    SELECT 'S'
                      INTO V_SINO
                      FROM ge_gru_transacciones_det a
                     WHERE a.cod_transaccion = P_COD_TRANSACCION
                       AND a.cod_modulo = P_COD_MODULO
                       AND a.cod_modalidad = P_COD_MODALIDAD
                       AND a.cod_gru_transaccion IN (82, 83)
                       AND ROWNUM = 1;
                 EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                       -- MDP-SEG_TAR_DEB / MDPSETADE-39: Para que no redondee el monto gravado
                       BEGIN
                          SELECT DISTINCT 'S'
                            INTO V_SINO
                            FROM ge_par_entes
                           WHERE parametro LIKE 'TRA_____SEG_TAR_DEB'
                             AND cod_ente = pag_deb.fu_obt_ente
                             AND val_parametro = P_COD_TRANSACCION;
                       EXCEPTION
                          WHEN NO_DATA_FOUND THEN
                            --verifico si la transaccion corresponde a un cargo de seguro
                             BEGIN
                                SELECT 'S'
                                   INTO v_sino
                                   FROM ge_sol_cargos x
                                 WHERE x.cod_modulo = p_cod_modulo
                                   AND x.cod_modalidad = p_cod_modalidad
                                   AND x.cod_transaccion = p_cod_transaccion
                                   AND x.cod_ent_seguro IS NOT NULL
                                   AND rownum = 1;
                             EXCEPTION
                               WHEN no_data_found THEN
                                  v_sino := 'N';
                             END;
                       END;
                 END;
           END;
   END;
  END IF;
  RETURN V_SINO;
END;

PROCEDURE PR_OBT_DAT_PERSONA
 (P_COD_MOD_PADRE IN NUMBER,
  P_COD_MAD_PADRE IN NUMBER,--AP3035
  P_COD_USUARIO IN VARCHAR2,
  P_FECHA IN DATE,
  P_HORA IN VARCHAR2,
  P_NRO_SECUENCIA IN NUMBER,
  P_NRO_CUENTA IN VARCHAR2,
  P_NRO_DOCUMENTO2 IN VARCHAR2,
  P_REFERENCIA IN VARCHAR2,
  P_COD_MONEDA IN VARCHAR2,
  P_MTO_IVA IN NUMBER,
  P_VAL_TASA IN NUMBER,
  P_COD_PERSONA in OUT VARCHAR2,
  P_NRO_DOCUMENTO OUT VARCHAR2,
  P_NOM_COMPLETO  OUT VARCHAR2) IS

  v_cod_mon_local ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_local;
  v_monto         number(18,2);
  v_mto_desvio    number(18,2);
  v_tip_persona   ba_personas.tipo%type;
  v_tip_iva       ba_personas.tip_iva%type;
BEGIN
  --Si la modalidad es Anticipo al exportador debe conservar el código de peresona del movimiento generado AP 3035
  if p_nro_cuenta is not null and p_cod_mad_padre <> 64 then
    begin
      p_cod_persona := fug_obt_cli_principal(p_nro_cuenta);
    exception
      when others then
        p_cod_persona := null;
    end;
  end if;

  if p_cod_persona is null and p_cod_mod_padre = 7 then
    begin
      select to_char(nro_documento2),
             decode(nvl(nro_documento2, 0), 0, concepto, fue_obt_nom_persona(nro_documento2)) nom_persona,
             referencia nro_documento
        into p_cod_persona,
             p_nom_completo,
             p_nro_documento
        from ge_movimientos
       where cod_usuario = p_cod_usuario
         and hora = p_hora
         and fecha = p_fecha
         and cod_mod_padre = 7
         and cod_transaccion = 760;
    exception
      when others then
        p_cod_persona := null;
    end;
    IF P_COD_PERSONA IS NULL AND P_NRO_DOCUMENTO2 IS NOT NULL THEN
       P_COD_PERSONA := P_NRO_DOCUMENTO2;
    END IF;
  end if;

  if p_cod_persona is null then
    if p_val_tasa > 0 then
       v_monto := (p_mto_iva * 100 / p_val_tasa) + p_mto_iva;
    end if;
    if p_cod_moneda = v_cod_mon_local then
      v_monto := abs(round(v_monto, 0));
      v_mto_desvio := 5;
    else
      v_monto := abs(round(v_monto, 2));
      v_mto_desvio := 0.1;
    end if;
      -- Cuando es Anticipo al exportador Asigna el código de persona del beneficiario de la CCE
      if p_cod_mad_padre = 64 then
        p_cod_persona := fux_obt_cce_beneficiario(null,p_nro_cuenta);
      end if;
    -- Busca la cuenta en el siguiente movimiento
    begin
      select decode(p_cod_mad_padre, 64, p_cod_persona,fug_obt_cli_principal(nro_cuenta))
        into p_cod_persona
        from ge_movimientos
       where cod_usuario = p_cod_usuario
         and hora = p_hora
         and fecha = p_fecha
         and nro_secuencia = nvl(p_nro_secuencia,0) + 1
         and nro_cuenta is not null
         and abs(monto) between v_monto - v_mto_desvio and v_monto + v_mto_desvio;
    exception
      when others then
        p_cod_persona := null;
    end;

    if p_cod_persona is null then
      begin
        -- Cobrado en efectivo
        select referencia
          into p_cod_persona
          from ge_movimientos
         where cod_usuario = p_cod_usuario
           and hora = p_hora
           and fecha = p_fecha
           and nro_secuencia = nvl(p_nro_secuencia,0) + 1
           and nro_cuenta is null
           and referencia is not null
           and cod_modulo = 9
           and abs(monto) between v_monto - v_mto_desvio and v_monto + v_mto_desvio;
      exception
        when others then
          p_cod_persona := null;
      end;
    end if;
  end if;

  if p_cod_persona is null then
    declare
      cursor c_mov is
      select cod_modulo, cod_modalidad, cod_transaccion, tip_mov_rubro, cod_rubro, monto, cod_moneda, val_tasa
        from ge_movimientos
       where cod_usuario = p_cod_usuario
         and hora = p_hora
         and fecha = p_fecha
         and cod_moneda = p_cod_moneda
         and val_tasa is not null;
     begin
       v_monto := 0;
       for m in c_mov loop
         if pab_iva.fu_mov_con_iva(m.cod_modulo, m.cod_modalidad, m.cod_transaccion, m.tip_mov_rubro, m.cod_rubro) = 'S' then
           if p_cod_moneda = v_cod_mon_local then
             v_monto := v_monto + abs(round((m.monto * 100 / m.val_tasa) + m.monto, 0));
             v_mto_desvio := 5;
           else
             v_monto := v_monto + abs(round((m.monto * 100 / m.val_tasa) + m.monto, 2));
             v_mto_desvio := 0.1;
           end if;
          end if;
       end loop;
       -- Cuando es Anticipo al exportador Asigna el código de persona del beneficiario de la CCE
       if p_cod_mad_padre = 64 then
          p_cod_persona := fux_obt_cce_beneficiario(null,p_nro_cuenta);
       end if;
       -- Busca el movimiento con cuenta que coincida el monto
       begin
         select decode(p_cod_mad_padre, 64, p_cod_persona,fug_obt_cli_principal(nro_cuenta))
           into p_cod_persona
           from ge_movimientos
          where cod_usuario = p_cod_usuario
            and hora = p_hora
            and fecha = p_fecha
            and nro_cuenta is not null
            and cod_modalidad in (31, 41)
            and abs(monto) between v_monto - v_mto_desvio and v_monto + v_mto_desvio;
       exception
         when others then
           p_cod_persona := null;
       end;
     end;
  end if;
  --

  -- codigo de persona
  if p_cod_persona is null then
       -- Cuando es Anticipo al exportador Asigna el código de persona del beneficiario de la CCE
     if p_cod_mad_padre = 64 then
        p_cod_persona := fux_obt_cce_beneficiario(null,p_nro_cuenta);
     end if;
       -- Busca si toda la operacion tiene una sola cuenta de debito
       begin
         select fug_obt_cli_principal(nro_cuenta)
           into p_cod_persona
           from ge_movimientos
          where cod_usuario = p_cod_usuario
            and hora = p_hora
            and fecha = p_fecha
            and nro_cuenta is not null
            and cod_modalidad in (31, 41);
       exception
         when others then
           p_cod_persona := null;
       end;

  end if;
  -- busco los demas datos de la persona si existe
  if p_cod_persona is not null then
    begin
      select cod_persona, nom_completo, nro_documento, tipo, tip_iva
        into p_cod_persona, p_nom_completo, p_nro_documento, v_tip_persona, v_tip_iva
        from ba_personas
       where cod_persona = p_cod_persona;
    exception
      when others then
        p_cod_persona := null;
    end;
  end if;
  if v_tip_persona = 'F' then
     begin
        select DECODE(NVL(v_tip_iva,'NC'),'NC',P_NRO_DOCUMENTO,P_NRO_DOCUMENTO||'-'||fue_obt_ruc_dig_verificador(P_NRO_DOCUMENTO))
          into p_nro_documento
          from ba_per_fisicas f
         where cod_persona = p_cod_persona;
     exception
        when others then null;
     end;
  end if;
END;

 -- genera los movimientos en tmp por los asientos manuales del dia
 procedure PR_GEN_LIB_VTA_TMP_ASI is
  rg_lib_ventas     cb_lib_ventas_det_tmp%rowtype;
  v_cod_mon_local   ba_monedas.cod_moneda%type;
  v_cod_persona     varchar2(20);
  v_nro_doc_persona varchar2(30);
  v_nom_completo    varchar2(200);
  cursor asientos is
    select b.fecha, b.cod_oficina, to_char(b.fec_insercion,'hh24:mi:ss') hora,
           a.nro_linea nro_secuencia, b.usu_insercion cod_usuario, --obs. Le agregué el código de usuario
           b.cod_modulo, b.cod_modalidad, 101 cod_tra_padre,
           a.mto_mon_local monto_iva,
           decode(a.cod_rubro,'240102440100199',10,5) tip_iva,
           a.mto_mon_local * 100 / decode(a.cod_rubro,'240102440100199',10,5) val_gravado,
           substr(a.descripcion,1,35) concepto, b.nro_asiento nro_documento,
           substr(a.referencia,1,10) cod_persona -- si el dato grabado en este campo es un codigo de persona, sino null
      from cb_asientos b,cb_asientos_det a
     where b.fecha = a.fecha
       and b.cod_oficina = a.cod_oficina
       and b.nro_asiento = a.nro_asiento
       and a.tip_movimiento = 'C'
       and a.cod_rubro in ('240102440100199','240102440100299') -- iva 1' 5 5% respectivamente
       and b.cod_modulo = 2 -- asientos manuales
       order by fecha, hora, cod_usuario;
begin
  v_cod_mon_local := pag_gen.fu_obt_mon_local;
  for m in asientos loop
    begin
      select cod_persona, nom_completo, nro_documento
        into v_cod_persona, v_nom_completo, v_nro_doc_persona
        from ba_personas
       where cod_persona = m.cod_persona;
    exception
      when no_data_found then
        v_cod_persona     := null;
        v_nom_completo    := null;
        v_nro_doc_persona := null;
      when others then
        rg_lib_ventas.error := substr('Error al Buscar Datos de la Persona en Asientos Automáticos fecha= '||
                             to_char(m.fecha,'dd/mm/yyyy')||
                             ' hora='||m.hora||' usuario='||m.cod_usuario,1,300);
    end;
    --Limpia el registro.
    rg_lib_ventas := null;
    -- Carga con ceros los montos.
    rg_lib_ventas.impuesto_10_gs := 0;
    rg_lib_ventas.mto_gra_10_gs  := 0;
    --
    rg_lib_ventas.mto_gravado_10 := 0;
    rg_lib_ventas.impuesto_10    := 0;
    --
    rg_lib_ventas.impuesto_5_gs  := 0;
    rg_lib_ventas.mto_gra_5_gs   := 0;
    --
    rg_lib_ventas.mto_gravado_5  := 0;
    rg_lib_ventas.impuesto_5     := 0;
    --
    rg_lib_ventas.mto_exento_gs  := 0;
    rg_lib_ventas.mto_exento     := 0;
    --
    if m.tip_iva = 10 then
      rg_lib_ventas.mto_gra_10_gs  := m.val_gravado;
      rg_lib_ventas.impuesto_10_gs := m.monto_iva;
      --
      rg_lib_ventas.mto_gravado_10 := m.val_gravado;
      rg_lib_ventas.impuesto_10    := m.monto_iva;
    elsif m.tip_iva = 5 then
      rg_lib_ventas.mto_gra_5_gs  := m.val_gravado;
      rg_lib_ventas.impuesto_5_gs := m.monto_iva;
      --
      rg_lib_ventas.mto_gravado_5 := m.val_gravado;
      rg_lib_ventas.impuesto_5    := m.monto_iva;
    end if;
    --
    rg_lib_ventas.cod_persona    := v_cod_persona;
    rg_lib_ventas.nro_doc_persona:= v_nro_doc_persona;
    rg_lib_ventas.nom_completo   := v_nom_completo;
    rg_lib_ventas.cod_ofi_origen := m.cod_oficina;
    rg_lib_ventas.cod_mod_padre  := m.cod_modulo;
    rg_lib_ventas.cod_mad_padre  := m.cod_modalidad;
    rg_lib_ventas.cod_tra_padre  := m.cod_tra_padre;
    rg_lib_ventas.nro_documento  := m.nro_documento;
    rg_lib_ventas.reversado      := 'N';
    rg_lib_ventas.fecha          := m.fecha;
    rg_lib_ventas.hora           := m.hora;
    rg_lib_ventas.cod_usuario    := m.cod_usuario;
    rg_lib_ventas.nro_factura    := 0;
    rg_lib_ventas.nro_timbrado   := 0;
    --
    rg_lib_ventas.nro_secuencia  := m.nro_secuencia;
    rg_lib_ventas.tip_venta      := 'CO';
    rg_lib_ventas.descripcion    := m.concepto;
    rg_lib_ventas.cod_moneda     := v_cod_mon_local;
    rg_lib_ventas.cotizacion     := 1;
    --
  rg_lib_ventas.cod_modulo:= m.cod_modulo;
    rg_lib_ventas.cod_modalidad:= m.cod_modalidad;
    rg_lib_ventas.cod_transaccion:= m.cod_tra_padre;
    begin
     pab_iva.pr_ins_lib_ven_tmp(rg_lib_ventas);
    exception
      when dup_val_on_index then
        --Si existe en entre los temporales limpia las variables.
        rg_lib_ventas := null;
      when others then
        raise_application_error(-20000,'Error al insertar datos en Libro Venta Temporal '||sqlerrm);
    end;
  end loop;
end;
-- generacion del tmp a partir de movimientos de tarjetas de credito
PROCEDURE PR_GEN_LIB_VTA_TMP_TAR is
  v_fec_inicio    date;
  v_fec_fin       date;
  rg_lib_ventas   cb_lib_ventas_det_tmp%rowtype;
  v_nro_secuencia cb_lib_ventas_det_tmp.nro_secuencia%type := 0;
  v_hora          cb_lib_ventas_det_tmp.hora%type := to_char(sysdate,'hh24:mi:ss');
  v_fecha         cb_lib_ventas_det_tmp.fecha%type;
  cursor tarjetas(p_fec_inicio date,
                  p_fec_fin    date) is
    select user cod_usuario, fec_cierre fecha,
           nro_secuencia,
           por_iva, -- tipo de iva
           mto_iva, -- iva
           mto_movimiento, -- mto gravado
           b.cod_persona, ---
           a.nro_cuenta, -- cuenta
           a.descripcion concepto,
           b.nom_completo,
           b.nro_documento,
           t.cod_modulo, t.cod_modalidad, 30 cod_transaccion,
           t.cod_oficina, t.cod_moneda, a.nro_orden
     from ba_personas b,
          ta_iva_cta_tmp a,
          ta_cta_tarjetas t,
          ge_cta_clientes gcc
    where a.fec_cierre between p_fec_inicio and p_fec_fin  -- inicio y mes actual
      and gcc.cod_persona = b.cod_persona
      and gcc.relacion = 'P'
      and gcc.nro_cuenta = t.nro_cuenta
      and to_char(to_number(a.nro_cuenta)) = t.nro_cuenta
     order by fecha;
begin
     -- solo se procesa si es fin de mes
    pag_cal.PR_OBT_DAT_CALENDAR(5);
    v_fec_inicio := pag_cal.G_PRI_DIA_MES;
    v_fec_fin    := pag_cal.G_ULT_DIA_MES;

    -- Verifica que no esté procesado
    declare
      v_existe varchar2(1);
    begin
      select distinct 'S' into v_existe
        from cb_lib_ventas_det_tmp x
       where x.fecha between v_fec_inicio and v_fec_fin
         and x.cod_mod_padre = 5
         and x.cod_tra_padre = 30;
       -- ya existe los registros
       raise_application_error(-20000,'El archivo de IVA del mes ya fue procesado');
    exception
      when no_data_found then
        null;
    end;

    -- Verifica si hay datos
    declare
      v_cantidad number(10);
    begin
      select count(*) into v_cantidad
        from ta_iva_cta_tmp a
       where a.fec_cierre between v_fec_inicio and v_fec_fin;  -- inicio y mes actual
      if v_cantidad = 0 then
        raise_application_error(-20000,'No hay registros de IVA a procesar');
      end if;
    end;

    for m in tarjetas(v_fec_inicio,v_fec_fin) loop
      v_fecha := m.fecha;
      if v_nro_secuencia = 999 then
        v_nro_secuencia := 0;
        v_hora := pag_gen.fu_obt_sig_segundo(v_hora);
      end if;
      v_nro_secuencia := v_nro_secuencia + 1;
      --Limpia el registro.
      rg_lib_ventas := null;
      -- Carga con ceros los montos.
      rg_lib_ventas.impuesto_10_gs := 0;
      rg_lib_ventas.mto_gra_10_gs  := 0;
      --
      rg_lib_ventas.mto_gravado_10 := 0;
      rg_lib_ventas.impuesto_10    := 0;
      --
      rg_lib_ventas.impuesto_5_gs  := 0;
      rg_lib_ventas.mto_gra_5_gs   := 0;
      --
      rg_lib_ventas.mto_gravado_5  := 0;
      rg_lib_ventas.impuesto_5     := 0;
      --
      rg_lib_ventas.mto_exento_gs  := 0;
      rg_lib_ventas.mto_exento     := 0;
      --
      if m.por_iva = 10 then
        rg_lib_ventas.mto_gra_10_gs  := m.mto_movimiento;
        rg_lib_ventas.impuesto_10_gs := m.mto_iva;
        --
        rg_lib_ventas.mto_gravado_10 := m.mto_movimiento;
        rg_lib_ventas.impuesto_10    := m.mto_iva;
      elsif m.por_iva = 5 then
        rg_lib_ventas.mto_gra_5_gs  := m.mto_movimiento;
        rg_lib_ventas.impuesto_5_gs := m.mto_iva;
        --
        rg_lib_ventas.mto_gravado_5 := m.mto_movimiento;
        rg_lib_ventas.impuesto_5    := m.mto_iva;
      end if;
      --
      rg_lib_ventas.cod_persona    := m.cod_persona;
      rg_lib_ventas.nro_doc_persona:= m.nro_documento;
      rg_lib_ventas.nom_completo   := m.nom_completo;
      rg_lib_ventas.cod_ofi_origen := m.cod_oficina;
      rg_lib_ventas.cod_mod_padre  := m.cod_modulo;
      rg_lib_ventas.cod_mad_padre  := m.cod_modalidad;
      rg_lib_ventas.cod_tra_padre  := m.cod_transaccion;
      rg_lib_ventas.nro_documento  := m.nro_orden;
      rg_lib_ventas.reversado      := 'N';
      rg_lib_ventas.fecha          := m.fecha;
      rg_lib_ventas.hora           := v_hora;
      rg_lib_ventas.cod_usuario    := m.cod_usuario;
      rg_lib_ventas.nro_factura    := 0;
      rg_lib_ventas.nro_timbrado   := 0;
      --
      rg_lib_ventas.nro_secuencia  := v_nro_secuencia;
      rg_lib_ventas.tip_venta      := 'CO';
      rg_lib_ventas.descripcion    := m.concepto;
      rg_lib_ventas.cod_moneda     := m.cod_moneda;
      rg_lib_ventas.cotizacion     := 1;
      --
    rg_lib_ventas.cod_modulo:= m.cod_modulo;
      rg_lib_ventas.cod_modalidad:= m.cod_modalidad;
      rg_lib_ventas.cod_transaccion:= m.cod_transaccion;
      begin
          pab_iva.pr_ins_lib_ven_tmp(rg_lib_ventas);
      exception
        when dup_val_on_index then
          --Si existe en entre los temporales limpia las variables.
          rg_lib_ventas := null;
        when others then
          raise_application_error(-20000,'Error al insertar datos en Libro Venta Temporal '||sqlerrm);
      end;
      --
    end loop;
end;
-- PROCEDIMIENTO PARA CORRER EN EL CIERRE
PROCEDURE PR_PRO_CIERRE IS
v_lugar varchar2(1000) := 'Inicio';
v_trunca_cab VARCHAR2(500) := 'truncate table cb_lib_ventas_tmp';
v_trunca_det VARCHAR2(500) := 'truncate table cb_lib_ventas_det_tmp';
V_FALSE BOOLEAN := FALSE;
V_VERDADERO BOOLEAN := TRUE;
v_nro_fac_generado  cb_lib_compras.nro_factura%type;

--Actualizar Notas del Credtitos del Mes--
PROCEDURE LP_ACT_NOT_CRE_DEL_MES IS
  --Proyecto SDDEC312NC-1 / Nota Crédito varias Facturas--
  --Variables--
  v_nro_factura cb_lib_ventas.nro_factura%type;
  v_nro_timbrado cb_lib_ventas.nro_timbrado%type;
  v_tra_car_interes ge_par_dinamicos.val_parametro%type;

  --Cursor--
  cursor c_not_creditos is
    select z.*, z.rowid reg_not_cre
      from cb_lib_ventas_det_tmp z
     where nvl(z.reversado,'N') = 'S'
       and z.nro_factura = '0'
       and z.cod_tra_padre in (359,360,362) --Cancelacion Anticipada--
       and z.cod_transaccion in (1708,2517); --Iva 10%--
  BEGIN
    v_tra_car_interes := fug_obt_pardinamico('COD_TRA_CAR_INTERES');
    for fac in c_not_creditos loop
        v_nro_factura := null;
        v_nro_timbrado := null;        
        begin
          select d.nro_factura, d.nro_timbrado
            into v_nro_factura, v_nro_timbrado
            from pr_cta_prestamos p, pr_movimientos_his m, cb_lib_ventas_det d
           where m.nro_cuenta = p.nro_cuenta
             and m.nro_cuenta = d.nro_cuenta
             and p.fec_inicio = m.fec_valor
             and d.fecha = m.fecha and d.hora = m.hora
             and d.nro_secuencia = m.nro_secuencia
             and d.cod_usuario = m.cod_usuario
             and m.cod_tra_padre = 358
             and m.cod_modulo = 6 and m.cod_transaccion IN (719,709)
             and p.nro_cuenta = fac.nro_cuenta
             and d.nro_factura is not null;
          exception
            when others then
               v_nro_factura  := null;
               v_nro_timbrado := null;
          end;        
          if ((v_nro_factura is null) and
              (instr(nvl(v_tra_car_interes, '0'), ','||fac.cod_tra_base||',') > 0)) then
             begin
               select d.nro_factura, d.nro_timbrado
                 into v_nro_factura, v_nro_timbrado
                 from cb_lib_ventas_det d, cb_lib_ventas e
                where d.nro_factura = e.nro_factura
                  and d.nro_timbrado = e.nro_timbrado
                  and e.tip_comprobante = 'F' --Factura--
                  and d.cod_tra_padre = 391 --CARGO IVA S/INTERES VENCIDO
                  and d.cod_mod_padre = 6
                  and d.cod_mad_padre = fac.cod_mad_padre
                  and d.cod_transaccion = 710 --IVA S/ INTERES - INGRESO AL FISCO SOBRE CUTOA VENCIDA
                  and d.nro_cuenta = fac.nro_cuenta
                  and d.nro_factura is not null
                  and d.mto_gravado_10 = fac.mto_gravado_10;
             exception
                when others then
                   v_nro_factura  := null;
                   v_nro_timbrado := null;
             end;
          end if;        
        if v_nro_factura is not null then
           update cb_lib_ventas_det_tmp y
              set y.nro_factura = v_nro_factura,
                  y.nro_timbrado = v_nro_timbrado
            where y.rowid = fac.reg_not_cre;
        end if;
    end loop;
  END;

BEGIN
   -- Registrar el nombre en action
   DBMS_APPLICATION_INFO.SET_ACTION('PAB_IVA');
   DBMS_APPLICATION_INFO.SET_CLIENT_INFO('PR_PRO_CIERRE, Iniciando');
   pag_cal.PR_OBT_DAT_CALENDAR(1);

   --PMN 27/01/2015 Para mejorar los tiempos del proceso: ITGF - Demora en el cierre SC 12794
   begin
     dbms_stats.gather_table_stats('IT','GE_MOVIMIENTOS');
   end;   
  
   -- DIARIAMENTE
   v_lugar  := 'PR_GEN_LIB_VTA_TMP';
   PR_GEN_LIB_VTA_TMP(NULL,NULL,NULL,NULL,null);     
   -- toma los movimientos del dia
   -- Operaciones de cambios (Venta) toma los movimientos del dia
   v_lugar  := 'PRB_GEN_LIB_VTA_CAMBIOS_TMP';
   PRB_GEN_LIB_VTA_CAMBIOS_TMP(null,null,null,null,null);
   -- Operaciones de cambios (Compra) toma los movimientos del dia
   v_lugar  := 'PRB_GEN_LIB_COM_CAMBIOS_TMP';
   PRB_GEN_LIB_COM_CAMBIOS_TMP(null,null,null,null,null);
   -- Generacion de Facturas(Compra/Venta) del dia
   v_lugar  := 'PR_GEN_FAC_CAMBIO';
   PR_GEN_FAC_CAMBIO(null,null,null,null);
   --Autofacturas por Retenciones INR
   v_lugar  := 'PRA_GEN_FAC_INR';
   PRA_GEN_FAC_INR(NULL, NULL, NULL,v_nro_fac_generado); 
    -- Actualizacion de Notas de Creditos temporales --Proyecto SDDEC312NC-6--
   v_lugar  := 'PRB_ACT_NOT_CREDITO';
   PRB_ACT_NOT_CREDITO; --Actualizacion diaria--
   -- MENSUAL
   if pag_cal.G_FEC_ACTUAL = pag_cal.G_ULT_DIA_MES_HABIL or fug_obt_pardinamico('CON_GEN_DIARIA') = 'S' then
       --       
       v_lugar  := 'Generacion de Factura';
       PR_GEN_FACTURA(NULL,NULL,NULL,NULL);  -- genera las facturas
       
       --Proyecto SDDEC312NC-1 / Nota Crédito varias Facturas--
       v_lugar  := 'Generacion de Nota de Crédito del mes';
       LP_ACT_NOT_CRE_DEL_MES;

       v_lugar  := 'Generacion de Nota de Credito';
       PR_GEN_NOT_CREDITO; -- genera las notas de credito

       v_lugar := 'Inserta los registros con observaciones';
       pr_ins_observaciones;
         --
       v_lugar := 'Trunca los temporales';
       EXECUTE IMMEDIATE v_trunca_cab;
       EXECUTE IMMEDIATE v_trunca_det;
   end if;
   -- LIMPIAR la salida
   DBMS_APPLICATION_INFO.SET_ACTION(NULL);
   DBMS_APPLICATION_INFO.SET_CLIENT_INFO(NULL); 
exception
  when others then
   -- LIMPIAR la salida
   DBMS_APPLICATION_INFO.SET_ACTION(NULL);
   DBMS_APPLICATION_INFO.SET_CLIENT_INFO(NULL); 
   raise_application_error(-20000,v_lugar||sqlerrm);
END;
--
/* Genera libro venta de las operaciones y retorna la factura */
FUNCTION FU_GEN_FACTURA
 (P_COD_PERSONA IN VARCHAR2
 ,P_FECHA IN DATE default null
 ,P_HORA IN varchar2 default null
 ,P_COD_USUARIO IN VARCHAR2 default null
 )
 RETURN VARCHAR2 IS
BEGIN
  PR_GEN_FACTURA(P_COD_PERSONA, P_FECHA, P_HORA,P_COD_USUARIO);
  RETURN v_nro_fac_retorno;
END;

/* Genera libro venta de las operaciones y retorna la nota de credito */
FUNCTION FU_GEN_NOT_CREDITO --BBVASOP-1209
 (P_COD_PERSONA   IN VARCHAR2
 ,P_FECHA         IN DATE     DEFAULT NULL
 ,P_HORA          IN VARCHAR2 DEFAULT NULL
 ,P_COD_USUARIO   IN VARCHAR2 DEFAULT NULL
 )
 RETURN VARCHAR2 IS
BEGIN
  PR_GEN_NOT_CREDITO(P_COD_PERSONA, P_FECHA, P_HORA,P_COD_USUARIO);
  RETURN v_nro_fac_retorno;
END;

/* OBTENGO EL CODIGO DE PERSONA */
FUNCTION  FU_OBT_COD_PERSONA
 (P_COD_MOD_PADRE IN NUMBER,
  P_COD_USUARIO IN VARCHAR2,
  P_FECHA IN DATE,
  P_HORA IN VARCHAR2,
  P_NRO_SECUENCIA IN NUMBER,
  P_NRO_CUENTA IN VARCHAR2,
  P_REFERENCIA IN VARCHAR2,
  P_COD_MONEDA IN VARCHAR2,
  P_MTO_IVA IN NUMBER,
  P_VAL_TASA IN NUMBER)
  RETURN VARCHAR2 IS
 P_COD_PERSONA VARCHAR2(40);
 P_NRO_DOCUMENTO VARCHAR2(50);
 P_NOM_COMPLETO VARCHAR2(300);
 BEGIN
    IF P_MTO_IVA <> 0 AND P_VAL_TASA IS NOT NULL THEN
    PR_OBT_DAT_PERSONA
     (P_COD_MOD_PADRE,
      null,
      P_COD_USUARIO,
      P_FECHA,
      P_HORA,
      P_NRO_SECUENCIA,
      P_NRO_CUENTA,
      P_REFERENCIA,
      null,
      P_COD_MONEDA,
      P_MTO_IVA,
      P_VAL_TASA,
      P_COD_PERSONA,
      P_NRO_DOCUMENTO,
      P_NOM_COMPLETO);
    ELSE
      RETURN NULL;
    END IF;
    RETURN P_COD_PERSONA;
  END;

/* Recupera y actualiza el nro. de factura utilizado */
PROCEDURE PR_OBT_NRO_FACTURA
 (p_cod_oficina in number
 ,p_fecha in date
 ,p_tip_comprobante in varchar2
 ,p_nro_factura out number
 ,p_nro_timbrado out varchar2
 ,p_fec_timbrado out date) IS

   v_rowid varchar2(30);
   v_fec_actual date;
   v_tip_facturacion cb_par_comprobantes.tip_facturacion%type;
   v_serie           cb_par_comprobantes.serie%type;
   v_serie_aux       cb_par_comprobantes.serie%type;
   v_act_fac_electronica ge_par_dinamicos.val_parametro%type;
   v_cantidad        cb_par_comprobantes.cantidad%type;
BEGIN
   v_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(2);
   v_act_fac_electronica := it.fug_obt_pardinamico('GE_ACT_FAC_ELECTRONICA');
   --si el parámetro de facturación electrónica está activa entonces busca por el tipo de facturación E
   if nvl(v_act_fac_electronica,'N') = 'S' and p_tip_comprobante <> 'R' then
   --- Verificar condiciones del timbrado
     select nvl(ult_nro_emitido + 1, nro_desde),
            c.nro_timbrado,
            c.fec_vencimiento,
            rowid,
            nvl(c.tip_facturacion,'N'),
            c.serie,
            c.cantidad
       into p_nro_factura,
            p_nro_timbrado,
            p_fec_timbrado,
            v_rowid,
            v_tip_facturacion,--Variable para Facturacion Electronica
            v_serie_aux,--Variable para Facturacion Electronica
            v_cantidad
       from cb_par_comprobantes c
      where cod_oficina = p_cod_oficina
        and tipo = p_tip_comprobante
        and c.tip_facturacion = 'E'
        and fec_vencimiento >= v_fec_actual
        and fec_vencimiento =
            (select max(fec_vencimiento)
               from cb_par_comprobantes t
              where t.cod_oficina = c.cod_oficina
                and t.tipo = c.tipo
                and t.tip_facturacion = c.tip_facturacion
                and (nro_desde+cantidad) >= nvl(ult_nro_emitido + 1, nro_desde))
        for update nowait;
   else
     --- Verificar condiciones del timbrado
     select nvl(ult_nro_emitido + 1, nro_desde),
            c.nro_timbrado,
            c.fec_vencimiento,
            rowid,
            nvl(c.tip_facturacion,'N'),
            c.serie,
            c.cantidad
       into p_nro_factura,
            p_nro_timbrado,
            p_fec_timbrado,
            v_rowid,
            v_tip_facturacion,--Variable para Facturacion Electronica
            v_serie_aux,--Variable para Facturacion Electronica
            v_cantidad
     from cb_par_comprobantes c
    where cod_oficina = p_cod_oficina
      and tipo = p_tip_comprobante
        and nvl(c.tip_facturacion,'N') = 'N'
      and fec_vencimiento >= v_fec_actual
      and fec_vencimiento =
          (select max(fec_vencimiento)
             from cb_par_comprobantes t
            where t.cod_oficina = c.cod_oficina
              and t.tipo = c.tipo
                and nvl(t.tip_facturacion,'N') = nvl(c.tip_facturacion,'N')
                and (nro_desde+cantidad) >= nvl(ult_nro_emitido + 1, nro_desde))
      for update nowait;
   end if;
   --Proyecto: Facturación Electrónica
   --Autor: mmelgarejo 05/09/2022
   --Consultar si el parametro dinamico GE_ACT_FAC_ELECTRONICA se encuentra activo “S”
   --debe tomar los datos del nuevo timbrado definido para facturación electrónica
   --Si el tipo de facturación es Normal, entonces trabaja como siempre
   IF v_tip_facturacion = 'N' THEN
   update cb_par_comprobantes
      set ult_nro_emitido = nvl(ult_nro_emitido + 1, nro_desde)
    where rowid = v_rowid;
   ELSE --Si el tipo de Facturación es E, entra a trabajar la modalidad de Facturacion Electronica
     if v_act_fac_electronica = 'S' then --Si FE está activa
       v_serie := IT.FUG_VAL_SERIE(p_nro_factura,
                                   v_serie_aux,
                                   v_cantidad,
                                   v_tip_facturacion,
                                   p_cod_oficina,
                                   p_fecha,
                                   p_nro_timbrado);
       if v_serie <> v_serie_aux then
         UPDATE cb_par_comprobantes
            SET ult_nro_emitido = p_nro_factura,
                serie = v_serie
          WHERE ROWID = v_rowid;
       else
         UPDATE cb_par_comprobantes
            SET ult_nro_emitido = p_nro_factura
          WHERE ROWID = v_rowid;
       end if;
     end if;
   END IF;
exception
   when no_data_found then
      raise_application_error(-20000,
      'No existe numeración p/comprobante '||p_tip_comprobante|| ' Oficina '||p_cod_oficina||' Fecha '||to_char(p_fecha,'DD/MM/YYYY'));
   when others then
     raise_application_error(-20000, 'modulo: '|| pae_cnf.g_cod_modulo || sqlcode || ' ' || sqlerrm);
      if sqlcode = -54 then  -- registro bloqueado por otro usuario
      raise_application_error(-20000,
      'Numeración p/comprobante '||p_tip_comprobante|| ' Oficina '||p_cod_oficina||' Fecha '||to_char(p_fecha,'DD/MM/YYYY')||' utilizado por otro Usuario. Vuelva a intentarlo.');
      else
      raise_application_error(-20000,
      'Numeración p/comprobante '||p_tip_comprobante|| ' Oficina '||p_cod_oficina||' Fecha '||to_char(p_fecha,'DD/MM/YYYY')||'-'||sqlerrm);
      end if;
END;
FUNCTION FU_OBT_ULT_NRO_EMITIDO
 (p_cod_oficina in number
 ,p_tip_comprobante in varchar2)
RETURN NUMBER IS
   v_ult_emitido cb_par_comprobantes.ult_nro_emitido%type;
BEGIN
   --- Verificar condiciones del timbrado
   select nvl(ult_nro_emitido,0)
     into v_ult_emitido
     from cb_par_comprobantes c
    where cod_oficina = p_cod_oficina
      and tipo = p_tip_comprobante
      and fec_vencimiento =
          (select max(fec_vencimiento)
             from cb_par_comprobantes t
            where t.cod_oficina = c.cod_oficina
              and t.tipo = c.tipo);
  return v_ult_emitido;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      return 0;
END;

--- Devuelve verdadero o falso a la verificacion de si el movimiento
--- ha sido facturado
FUNCTION FU_MOV_FACTURADO
 (P_FECHA IN DATE,
  P_HORA IN VARCHAR2,
  P_COD_USUARIO IN VARCHAR2)
RETURN BOOLEAN IS
   v_existe varchar2(01);
BEGIN
   select 1 into v_existe
     from cb_lib_ventas_det d
    where d.fecha = p_fecha
      and d.hora = p_hora
      and d.cod_usuario = p_cod_usuario;
   return true;
exception
   when no_data_found then
      return false;
   when too_many_rows then
      return true;
   when others then
      return false;
END;

/* devuelve el codigo del rubro correspondiente al cargo asociado al iva */
FUNCTION FU_OBT_RUB_CARGO(p_fecha in date, p_cod_usuario in varchar2, p_hora in varchar2, p_nro_secuencia in number)
 RETURN VARCHAR2 IS
  --- Cursor Secundario de movimimientos
  cursor secundario(p_fecha in date, p_cod_usuario in varchar2, p_hora in varchar2, p_nro_secuencia in number) is
   select m.nro_secuencia, m.cod_modulo, m.cod_modalidad, m.cod_transaccion, m.cod_moneda, m.monto, m.mto_equ_local,
          m.concepto, m.val_tasa, m.nro_cuenta, m.referencia, m.tip_mov_rubro, m.cod_rubro
    from ge_movimientos m
   where fecha = p_fecha
     and cod_usuario = p_cod_usuario
     and hora = p_hora
     and m.cod_tra_padre not in (900) -- devengado
     and nro_secuencia < p_nro_secuencia
   order by FECHA, HORA, COD_USUARIO, NRO_SECUENCIA desc;
v_cod_rubro varchar2(20) := null;
BEGIN

   -- Movimientos con Cargos.
   for b in secundario(p_fecha, p_cod_usuario, p_hora, p_nro_secuencia) loop
      if pab_iva.fu_mov_cargo(b.cod_modulo, b.cod_modalidad, b.cod_transaccion, b.tip_mov_rubro, b.cod_rubro)  = 'S' then
         if b.cod_rubro is not null then
             v_cod_rubro := b.cod_rubro;
         else
             declare
                 cursor datos is select  c.cod_sec_contable,
                                         c.cod_tip_deudor,
                                         c.residente,
                                         1 cod_plazo,
                                         'C' tip_movimiento,
                                         a.cod_sit_contable
                                    from ge_clientes c,ge_cta_clientes b, ge_cuentas a
                                   where a.nro_cuenta = b.nro_cuenta
                                     and b.nro_cuenta = a.nro_cuenta
                                     and b.relacion = 'P'
                                     and c.cod_persona = b.cod_persona;
                 reg datos%rowtype;
              begin
                  open datos;
                  fetch datos into reg;
                  close datos;

                  v_cod_rubro := LF_OBT_COD_RUBRO(b.cod_modulo, b.cod_modalidad, b.cod_transaccion, b.cod_moneda,
                                   reg.cod_sec_contable, reg.cod_tip_deudor, reg.residente, reg.cod_plazo,
                                   reg.tip_movimiento,reg.cod_sit_contable);
              end;
         end if;

      end if;
   end loop;
   return v_cod_rubro;
END;

/******************JIRA 2735- Mejoras Proc. IVA  21-12-2012 -PS-******************/
PROCEDURE PR_ACT_EQU_LOCAL(P_FECHA       IN DATE     DEFAULT NULL,
                           P_HORA        IN VARCHAR2 DEFAULT NULL,
                           P_COD_USUARIO IN VARCHAR2 DEFAULT NULL) is
 /*****************************************************************
 * Creado para realizar los ajustes IVA de movimientos realizados
   en moneda extranjera.
   Descripción: Toma el total del  movimiento (monto equivalente en
   moneda local) y halla el monto gravado y luego por diferencia el iva.
   Para los movimientos en que tiene mas de un monto gravado y al final el
   Iva de todos ellos, la diferencia resultante del Iva se divide por la
   cantidad de montos gravados y se realiza el ajuste por esa cantidad
   proporcionalmente para cada monto.
 * Autor : Elisa Cantero
 * Fecha : 23/11/2010
 *****************************************************************/
 v_mon_local         ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_local;
 v_nro_secuencia     ge_movimientos.nro_secuencia%type;
 v_monto             ge_movimientos.monto%type;
 v_mto_equ_local     ge_movimientos.mto_equ_local%type;
 v_cotizacion        ge_movimientos.cotizacion%type;
 v_nro_sec_inicial   ge_movimientos.nro_secuencia%type :=0;
 v_nro_sec_final     ge_movimientos.nro_secuencia%type;
 v_nvo_iva_local     ge_movimientos.mto_equ_local%type;
 v_mto_ajuste        ge_movimientos.mto_equ_local%type;
 v_mto_gra_extr      ge_movimientos.monto%type;
 v_mto_gra_local     ge_movimientos.mto_equ_local%type;
 v_mto_iva_local     ge_movimientos.mto_equ_local%type;
 v_mto_iva_extr      ge_movimientos.monto%type;
 v_mto_iva_calc      ge_movimientos.monto%type;
 v_mto_total         ge_movimientos.mto_equ_local%type;
 v_aux_imp           ge_movimientos.mto_equ_local%type;
 v_diferencia        ge_movimientos.mto_equ_local%type;
 v_error             ge_log_act_dif_iva.det_error%type;
 v_redondeo          number(5) := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',null,null,v_mon_local,null);
 v_sale_while        varchar2(1);
 v_can_reg           number(20);
 ---------------------------------------------------------
 /* Cursor de los Movimientos de Iva Venta*/
 ---------------------------------------------------------
 cursor cur_iva is
  select a.fecha, a.hora, a.cod_usuario, a.nro_secuencia, a.monto,
         a.mto_equ_local, a.cotizacion, a.val_tasa
    from ge_movimientos a
   where a.cod_moneda <> v_mon_local
     and nvl(a.val_tasa,0) > 0
     and nvl(a.monto,0)<> 0
     and nvl(a.mto_equ_local,0)<> 0
     and a.estado = 'N' -- solo entraran los estados normales (especificacion de Basilia)
     and a.reversado = 'N'-- solo entraran los no reversados ( especificacion de Basilia)
     and (cod_usuario = p_cod_usuario or p_cod_usuario is null)
     and (fecha = p_fecha or p_fecha is null)
     and (hora = p_hora or p_hora is null)
     and pab_iva.fu_mov_con_iva(a.cod_modulo, a.cod_modalidad,a.cod_transaccion,null,null)='S'
     ---------------------------------------
    /*JIRA 2735- Mejoras Proc. IVA*/
    and a.cod_tra_padre not in ('370','391')
    and a.cod_usu_reversion is null
    ----------------------------------------
     and exists (select 'S'
                   from ge_movimientos b
                  where b.fecha = a.fecha
                    and b.hora  = a.hora
                    and b.cod_usuario   = a.cod_usuario
                    and b.nro_secuencia = a.nro_secuencia - 1)
     order by a.fecha, a.hora, a.cod_usuario, a.nro_secuencia asc;

 ----------------------------------------------------------------
  /* Procedimiento que registra el LOG */
 ----------------------------------------------------------------
 Procedure lp_reg_log  (p_fecha             in date,
                        p_hora              in varchar2,
                        p_cod_usuario       in varchar2,
                        p_nro_secuencia     in number,
                        p_monto             in number,
                        p_error             in varchar2) is
  PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
  begin
     insert into ge_log_act_dif_iva
       (fecha, hora, cod_usuario, nro_secuencia, monto, det_error)
     values
       (p_fecha, p_hora, p_cod_usuario, p_nro_secuencia, p_monto, substr(p_error,1,1000));
     commit;
  exception
     when others then null;
  end;
 --------------------------------------------------------------
 /* Procedimiento que calcula el/los monto/s Gravado/s */
 --------------------------------------------------------------
 Procedure lp_mto_movimiento(p_fecha         in ge_movimientos.fecha%type
                            ,p_hora          in ge_movimientos.hora%type
                            ,p_cod_usuario   in ge_movimientos.cod_usuario%type
                            ,p_nro_secuencia in ge_movimientos.nro_secuencia%type
                            ,p_monto         in ge_movimientos.monto%type -- monto iva moneda extranjera
                            ,p_mto_equ_local in ge_movimientos.mto_equ_local%type --monto iva moneda local
                            ,p_val_tasa      in ge_movimientos.val_tasa%type)IS --valor de lasa ( 5%, 10%)

 Begin

   v_mto_iva_local   := nvl(p_mto_equ_local,0); -- monto del iva en moneda local recibido como parametro
   v_mto_iva_extr    := nvl(p_monto,0); --monto del iva en moneda extranjera recibido como parametro
   v_nro_secuencia   := fu_obt_sec_anterior(p_fecha,p_hora,p_cod_usuario,p_nro_secuencia);
   v_nro_sec_final   := v_nro_secuencia;
   v_mto_ajuste      := 0;
   v_mto_gra_extr    := 0;
   v_mto_gra_local   := 0;
   v_sale_while      :='N';
   v_diferencia      := 0;
   v_can_reg         := 0;
   v_nvo_iva_local   := 0;
   While (v_sale_while = 'N')
     Loop
       Select b.monto,b.mto_equ_local
         into v_monto,v_mto_equ_local
         from ge_movimientos b
        where b.fecha = p_fecha
          and b.hora  = p_hora
          and b.cod_usuario   = p_cod_usuario
          and b.nro_secuencia = v_nro_secuencia
          and b.cod_moneda <> v_mon_local
          order by b.nro_secuencia asc;

          v_mto_gra_local  := nvl(v_mto_gra_local,0) + nvl(v_mto_equ_local,0); -- monto gravado en moneda local del select
          v_mto_gra_extr   := nvl(v_mto_gra_extr,0) + nvl(v_monto,0); -- monto gravado en moneda extranjera del select
          /* Se debe calcular el iva del monto gravado en moneda extranjera del select */
          v_mto_iva_calc := round((v_mto_gra_extr * p_val_tasa / 100),2);

          if nvl(v_mto_iva_extr,0)  =  nvl(v_mto_iva_calc,0) or
             abs(nvl(v_mto_iva_calc,0) - nvl(v_mto_iva_extr,0)) between 0.01 and 0.04 then
              v_nro_sec_inicial    := v_nro_secuencia;
              v_sale_while         := 'S';
              v_mto_total          := nvl(round(v_mto_gra_local) + round(v_mto_iva_local),0);
              v_aux_imp            := 1 + round(100/p_val_tasa);
              v_nvo_iva_local      := round(v_mto_total / v_aux_imp);
          else
              v_nro_secuencia := fu_obt_sec_anterior(p_fecha,p_hora,p_cod_usuario,v_nro_secuencia);
          end if;
          v_can_reg  := v_can_reg + 1;
     End Loop;
     v_diferencia  := nvl(v_mto_iva_local - v_nvo_iva_local,0);
     v_mto_ajuste  := nvl(v_diferencia / v_can_reg,0);
 Exception
    When No_Data_Found THEN
      Null;
    When Others Then
       raise_application_error(-20001,'Error en el proceso lp_mto_movimiento'||' '||sqlerrm);
 End;
 ----------------------------------------------------------------
  /* Procedimiento que actualiza el movimiento */
 ----------------------------------------------------------------
 Procedure lp_act_movimiento (p_fecha         in date
                             ,p_hora          in varchar2
                             ,p_cod_usuario   in varchar2
                             ,p_nro_secuencia in number
                             ,p_monto         in number -- monto del iva o monto a ajustar para las gravadas
                             ,p_orden         in number)is
 begin
      If p_orden = 1 then  -- Si Orden = 1 es iva
       begin
         update ge_movimientos b
            set b.mto_equ_local = round(p_monto)
          where b.fecha = p_fecha
            and b.hora  = p_hora
            and b.cod_usuario   = p_cod_usuario
            and b.nro_secuencia = p_nro_secuencia;
       exception
            when others then
              v_error   := 'En orden ' || p_orden ||'-'||sqlerrm ;
              lp_reg_log (p_fecha,p_hora ,p_cod_usuario ,p_nro_secuencia, p_monto, v_error );
              raise;
       End;
      end if;

      If p_orden = 2 then -- Si Orden = 2 es monto gravado
         If p_monto < 0 then -- si el monto es negativo
            begin
               update ge_movimientos b
                  set b.mto_equ_local = round(b.mto_equ_local + p_monto)  -- debe sumar tambien ya que el monto a ajustar es negativo y por suma algebraica se produce la resta.
                where b.fecha = p_fecha
                  and b.hora  = p_hora
                  and b.cod_usuario   = p_cod_usuario
                  and b.nro_secuencia = p_nro_secuencia;
            exception
            when others then
              v_error   := 'En orden ' || p_orden || ' Mto. gravado es negativo. '||sqlerrm;
              lp_reg_log (p_fecha,p_hora ,p_cod_usuario ,p_nro_secuencia, p_monto, v_error );
              raise;
            End;
         else -- si el monto es positivo
           begin
               update ge_movimientos b
                  set b.mto_equ_local = round(b.mto_equ_local + p_monto)  -- suma el monto de ajuste a cada movimiento directamente
                where b.fecha = p_fecha
                  and b.hora  = p_hora
                  and b.cod_usuario   = p_cod_usuario
                  and b.nro_secuencia = p_nro_secuencia;
            exception
            when others then
              v_error   := 'En orden ' || p_orden || ' Mto. gravado es positivo. '||sqlerrm;
              lp_reg_log (p_fecha,p_hora ,p_cod_usuario ,p_nro_secuencia, p_monto, v_error );
              raise;
            End;
         end if;
      end if;
  Exception
     When Others Then
      raise_application_error(-20002,'Error en el proceso lp_act_movimiento'||' '||sqlerrm);
 end;
 ----------------------------------------------------------------
  /* Procedimiento que actualiza el monto equivalente local */
 ----------------------------------------------------------------
PROCEDURE lp_act_equ_local IS
   -- Cursor para obtener los movimientos
   CURSOR cu_movimientos IS
      SELECT fecha,
             hora,
             cod_usuario,
             nro_secuencia,
             monto,
             cod_moneda
        FROM ge_movimientos
       WHERE cod_moneda <> v_mon_local
         AND ABS(monto) > 0 -- DYDMR-10427
         AND mto_equ_local IS NULL;

   -- Variables para BULK COLLECT
   TYPE movimiento_rec IS RECORD (
      fecha        ge_movimientos.fecha%TYPE,
      hora         ge_movimientos.hora%TYPE,
      cod_usuario  ge_movimientos.cod_usuario%TYPE,
      nro_secuencia ge_movimientos.nro_secuencia%TYPE,
      monto        ge_movimientos.monto%TYPE,
      cod_moneda   ge_movimientos.cod_moneda%TYPE
   );
   TYPE movimiento_tbl IS TABLE OF movimiento_rec;
   movimientos movimiento_tbl;

   -- Cotizaciones calculadas
   TYPE cotizacion_tbl IS TABLE OF ge_movimientos.cotizacion%TYPE;
   cotizaciones cotizacion_tbl;

BEGIN
   -- Cargar datos del cursor en una colección
   OPEN cu_movimientos;
   LOOP
      FETCH cu_movimientos BULK COLLECT INTO movimientos LIMIT 2500; -- Procesar en bloques
      EXIT WHEN movimientos.COUNT = 0;

      -- Obtener las cotizaciones para los registros
      cotizaciones := cotizacion_tbl();
      FOR i IN 1 .. movimientos.COUNT LOOP
         cotizaciones.EXTEND;
         cotizaciones(i) := pag_gen.fu_obt_cotizacion(movimientos(i).cod_moneda);
      END LOOP;

      -- Aplicar actualizaciones en bloque
      FORALL i IN INDICES OF movimientos
         UPDATE ge_movimientos
            SET mto_equ_local = ROUND((movimientos(i).monto * cotizaciones(i)), v_redondeo),
                cotizacion = cotizaciones(i)
          WHERE fecha = movimientos(i).fecha
            AND hora = movimientos(i).hora
            AND cod_usuario = movimientos(i).cod_usuario
            AND nro_secuencia = movimientos(i).nro_secuencia;
   END LOOP;

   CLOSE cu_movimientos;

EXCEPTION
   WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20003, 'Error en el proceso lp_act_equ_local ' || SQLERRM);
END;
 --------------------------------------------------------------------------------------------------
 --------------------------------------PRINCIPAL---------------------------------------------------
 --------------------------------------------------------------------------------------------------
BEGIN
    /*actualiza el mto_equ_local*/
    lp_act_equ_local;
    /*Cursor de IVA Venta*/
    for c in cur_iva loop
       --Encuentra la Sencuencia inicial, Secuencia final, Monto Total Moneda Local, Iva en Moneda Local
       lp_mto_movimiento(c.fecha,c.hora,c.cod_usuario,c.nro_secuencia,c.monto,c.mto_equ_local,c.val_tasa);
       --Si hay diferencias entre el Iva en Moneda local gravado y el calculado realiza la actualización
       if nvl(v_mto_iva_local,0) <> nvl(v_nvo_iva_local,0) then
          lp_act_movimiento (c.fecha, c.hora, c.cod_usuario,v_nro_sec_final + 1, v_nvo_iva_local,1); -- actualiza el iva
            For i in v_nro_sec_inicial..v_nro_sec_final loop
               lp_act_movimiento (c.fecha, c.hora, c.cod_usuario, i, v_mto_ajuste,2); --actualiza los montos gravados
            End Loop;
       end if;
    end loop;
EXCEPTION
  WHEN OTHERS THEN
      raise_application_error(-20000,'Error en el Proceso de Diferencia de Iva Venta / Compra'||' '||sqlerrm);
END PR_ACT_EQU_LOCAL;

-----
/* Insertar en la tabla de observaciones de los temporales los registros que tuvieron ERROR */
PROCEDURE PR_INS_OBSERVACIONES (P_FEC_TMP   IN cb_lib_ventas_det_tmp.Fecha%type       DEFAULT NULL,
                                P_HOR_TMP   IN cb_lib_ventas_det_tmp.hora%type        DEFAULT NULL,
                                P_USU_TMP   IN cb_lib_ventas_det_tmp.cod_usuario%type DEFAULT NULL,
                                P_REVERSADO IN cb_lib_ventas_det_tmp.reversado%type   DEFAULT NULL)IS

/* Se comenta el cursor, ya que no se utilizará para la inserción en la tabla cb_obs_lib_ventas_tmp */
   /*
   CURSOR c_cabecera IS
      SELECT nro_factura,
             nro_timbrado,
             fecha,
             cod_oficina,
             tip_comprobante,
             tip_venta,
             cod_persona,
             nom_completo,
             nro_documento,
             mto_exento,
             mto_gravado_5,
             mto_gravado_10,
             impuesto_5,
             impuesto_10,
             dig_verificador,
             nro_fac_referencia,
             nro_tim_referencia,
             impreso,
             procesado,
             hora,
             cod_usuario,
             reversado
        FROM cb_lib_ventas_tmp m
       WHERE EXISTS (SELECT 1
                       FROM cb_lib_ventas_det_tmp d
                      WHERE d.fecha = m.fecha
                        AND d.hora = m.hora
                        AND d.cod_usuario = m.cod_usuario
                        AND ((d.error IS NOT NULL OR nvl(d.reversado, 'N') = 'S') AND p_reversado IS NULL)
                         OR (nvl(p_reversado, 'N') = 'S'
                             AND d.fecha       = p_fec_tmp
                             AND d.hora        = p_hor_tmp
                             AND d.cod_usuario = p_usu_tmp));
   */
   CURSOR c_detalles IS
      SELECT cod_persona,
             fecha,
             hora,
             cod_usuario,
             nro_secuencia,
             cod_ofi_origen,
             tip_comprobante,
             tip_venta,
             cod_tra_padre,
             nro_documento,
             descripcion,
             cod_moneda,
             mto_exento,
             mto_exento_gs,
             mto_gravado_5,
             mto_gra_5_gs,
             mto_gravado_10,
             mto_gra_10_gs,
             impuesto_5,
             impuesto_5_gs,
             impuesto_10,
             impuesto_10_gs,
             cotizacion,
             reversado,
             nom_completo,
             nro_doc_persona,
             nro_cuenta,
             nro_factura,
             nro_timbrado,
             error,
             aju_impuesto_5,
             aju_impuesto_10,
             cod_mod_padre,
             cod_mad_padre
        FROM cb_lib_ventas_det_tmp d
       WHERE ((d.error IS NOT NULL OR nvl(d.reversado, 'N') = 'S') AND p_reversado IS NULL)
          OR (nvl(p_reversado, 'N') = 'S'
              AND d.fecha       = p_fec_tmp
              AND d.hora        = p_hor_tmp
              AND d.cod_usuario = p_usu_tmp);

v_error     cb_obs_lib_ventas_det_tmp.error%type;
v_reversado cb_obs_lib_ventas_det_tmp.reversado%type;

BEGIN
  /* Se comenta el insert a la tabla cb_obs_lib_ventas_tmp
     ya que la misma se utiliza como temporal de la generación del libro Hechauka. */
  /*
   FOR c IN c_cabecera LOOP
      if nvl(p_reversado, 'N') = 'S' then
         v_reversado := 'S';
      else
         v_reversado := c.reversado;
      end if;
      BEGIN
         INSERT INTO cb_obs_lib_ventas_tmp
            (nro_factura, nro_timbrado, fecha, cod_oficina, tip_comprobante, tip_venta, cod_persona,
             nom_completo, nro_documento, mto_exento, mto_gravado_5, mto_gravado_10, impuesto_5,
             impuesto_10, dig_verificador, nro_fac_referencia, nro_tim_referencia, impreso,
             procesado, hora, cod_usuario, reversado)
         VALUES
            (c.nro_factura, c.nro_timbrado, c.fecha, c.cod_oficina, c.tip_comprobante, c.tip_venta,
             c.cod_persona, c.nom_completo, c.nro_documento, c.mto_exento, c.mto_gravado_5,
             c.mto_gravado_10, c.impuesto_5, c.impuesto_10, c.dig_verificador, c.nro_fac_referencia,
             c.nro_tim_referencia, c.impreso, c.procesado, c.hora, c.cod_usuario, v_reversado);
      EXCEPTION
         WHEN dup_val_on_index THEN
            --Si existe en el histórico deja sin efecto, pues al final se tiene que truncar la tabla.
            NULL;
         WHEN OTHERS THEN
            raise_application_error(-20000,'Error en PR_INS_OBSERVACIONES '||sqlerrm);
      END;
   END LOOP;
   */
   FOR m IN c_detalles LOOP
      if nvl(p_reversado, 'N') = 'S' then
         v_error     := 'Operación Reversada';
         v_reversado := 'S';
      else
         v_error     := m.error;
         v_reversado := m.reversado;
      end if;
      BEGIN
         INSERT INTO cb_obs_lib_ventas_det_tmp
            (cod_persona, fecha, hora, cod_usuario, nro_secuencia, cod_ofi_origen, tip_comprobante,
             tip_venta, cod_tra_padre, nro_documento, descripcion, cod_moneda, mto_exento,
             mto_exento_gs, mto_gravado_5, mto_gra_5_gs, mto_gravado_10, mto_gra_10_gs, impuesto_5,
             impuesto_5_gs, impuesto_10, impuesto_10_gs, cotizacion, reversado, nom_completo,
             nro_doc_persona, nro_cuenta, nro_factura, nro_timbrado, error, aju_impuesto_5,
             aju_impuesto_10, cod_mod_padre, cod_mad_padre)
         VALUES
            (m.cod_persona, m.fecha, m.hora, m.cod_usuario, m.nro_secuencia, m.cod_ofi_origen,
             m.tip_comprobante, m.tip_venta, m.cod_tra_padre, m.nro_documento, m.descripcion,
             m.cod_moneda, m.mto_exento, m.mto_exento_gs, m.mto_gravado_5, m.mto_gra_5_gs,
             m.mto_gravado_10, m.mto_gra_10_gs, m.impuesto_5, m.impuesto_5_gs, m.impuesto_10,
             m.impuesto_10_gs, m.cotizacion, v_reversado, m.nom_completo, m.nro_doc_persona,
             m.nro_cuenta, m.nro_factura, m.nro_timbrado, v_error, m.aju_impuesto_5,
             m.aju_impuesto_10, m.cod_mod_padre, m.cod_mad_padre);
      EXCEPTION
        WHEN dup_val_on_index THEN
            --Si existe en el histórico deja sin efecto, pues al final se tiene que truncar la tabla.
            NULL;
        WHEN OTHERS THEN
            raise_application_error(-20001,'Error en PR_INS_OBSERVACIONES '||sqlerrm);
      END;
   END LOOP;
   COMMIT;
END;

/* Insertar detalle del Libro Compra Temporal */
PROCEDURE PR_INS_LIB_COM_TMP
 (RP_BLCDT IN CB_LIB_COMPRAS_DET_TMP%ROWTYPE
 )
 IS
 v_cantidad number;
begin
   select nvl(count(*),0)
     into v_cantidad
     from cb_lib_compras_det
    where fecha =  rp_blcdt.fecha
      and hora =  rp_blcdt.hora
      and cod_usuario =  rp_blcdt.cod_usuario
      and nro_secuencia = rp_blcdt.nro_secuencia
      and rownum = 1;

   if v_cantidad = 0 then
     insert into cb_lib_compras_det_tmp(
        cod_persona, fecha, hora, cod_usuario, nro_secuencia,
        tip_comprobante, tip_compra,
        cod_ofi_origen, cod_mod_padre, cod_mad_padre, cod_tra_padre,
        nro_documento, descripcion,
        cod_moneda, mto_exento, mto_exento_gs, mto_gravado_5,
        mto_gra_5_gs, mto_gravado_10, mto_gra_10_gs, impuesto_5,
        impuesto_5_gs, impuesto_10, impuesto_10_gs, cotizacion,
        reversado, nom_completo, nro_doc_persona,
        nro_cuenta,nro_factura,nro_timbrado,error,aju_impuesto_5,aju_impuesto_10,can_cuota,
        cod_modulo,cod_modalidad,cod_transaccion,referencia)
     values(
        rp_blcdt.cod_persona, rp_blcdt.fecha, rp_blcdt.hora, rp_blcdt.cod_usuario,  rp_blcdt.nro_secuencia,
        rp_blcdt.tip_comprobante, rp_blcdt.tip_compra,
        rp_blcdt.cod_ofi_origen, rp_blcdt.cod_mod_padre, rp_blcdt.cod_mad_padre, rp_blcdt.cod_tra_padre,
        rp_blcdt.nro_documento, rp_blcdt.descripcion,
        rp_blcdt.cod_moneda, rp_blcdt.mto_exento, rp_blcdt.mto_exento_gs, rp_blcdt.mto_gravado_5,
        rp_blcdt.mto_gra_5_gs, rp_blcdt.mto_gravado_10, rp_blcdt.mto_gra_10_gs, rp_blcdt.impuesto_5,
        rp_blcdt.impuesto_5_gs, rp_blcdt.impuesto_10, rp_blcdt.impuesto_10_gs, rp_blcdt.cotizacion,
        rp_blcdt.reversado,rp_blcdt.nom_completo,rp_blcdt.nro_doc_persona, rp_blcdt.nro_cuenta,
        rp_blcdt.nro_factura,rp_blcdt.nro_timbrado, rp_blcdt.error, rp_blcdt.aju_impuesto_5, rp_blcdt.aju_impuesto_10,
        rp_blcdt.can_cuota,
        rp_blcdt.cod_modulo,rp_blcdt.cod_modalidad,rp_blcdt.cod_transaccion, rp_blcdt.referencia);
   end if;
end;

/* Genera Libro Venta/Compra de las Operaciones de Cambios. CNFNORMA-18-CNF-RABP:10-2016*/
PROCEDURE PR_GEN_FAC_CAMBIO
 (P_COD_PERSONA IN VARCHAR2 := null
 ,P_FECHA IN DATE := null
 ,P_HORA IN varchar2 := null
 ,P_COD_USUARIO IN VARCHAR2 := null
 )
 IS
--- Variables de corte de control
   v_cod_persona  cb_lib_ventas.cod_persona%type;
   v_nro_tim_fac  cb_lib_ventas.nro_timbrado%type;
   v_fec_vig_tim  date;
   rv_blven       cb_lib_ventas%rowtype;
   rv_blvde       cb_lib_ventas_det%rowtype;
   rv_blcom       cb_lib_compras%rowtype;
   rv_blcde       cb_lib_compras_det%rowtype;
   v_nro_factura  cb_lib_ventas.nro_factura%type;
   v_fec_proceso  date;
   v_nro_lin_fac  number(8);  -- Nro. de Lineas que puede tener una factura
   v_nro_linea    number(8);  -- Cantidad de lineas impresas de la factura
   v_cod_oficina  number(3);
   v_tip_venta    cb_lib_ventas.tip_venta%type;
   v_tip_compra   cb_lib_compras.tipo%type;
   v_cod_mon_factura varchar2(5);
   v_pun_expedicion number(3); -- Punto de Expedicion del comprobante
   v_lugar varchar2(1000) := null;
   v_cod_ofi_hacienda ba_oficinas.cod_oficina%type;
   v_borrado          NUMBER := 0; --bandera para borrar cabecera cb_lib_ventas_tmp
   v_max_cuota        cb_lib_ventas.can_cuota%type := 0;
   v_auxiliar         cb_lib_ventas.can_cuota%type := 0;
   v_mensaje          varchar2(100);
   --> CNFFAOCA-1-CNF-MB: 11/12/2015, Facturas de Operaciones de Cambios
   v_tip_comprobante  cb_lib_ventas.tip_comprobante%type;
   v_fec_aut_timbrado cb_par_comprobantes.fec_ini_timbrado%type;
   --- Cursor de movimientos de la persona por factura
   cursor c_facturas is
     -- cursor c_ventas
     select nvl(v.cod_persona,0)cod_persona, v.fecha, v.hora, v.cod_usuario, v.nro_secuencia, v.cod_ofi_origen,
            v.tip_comprobante, v.tip_venta tip_factura,
            v.cod_mod_padre, v.cod_mad_padre, v.cod_tra_padre,
            v.descripcion,
            v.cod_moneda, v.mto_exento, v.mto_exento_gs, v.mto_gravado_5, v.mto_gra_5_gs,
            v.mto_gravado_10, v.mto_gra_10_gs, v.impuesto_5, v.impuesto_5_gs,
            v.impuesto_10, v.impuesto_10_gs, v.cotizacion, nvl(c.cod_oficina,v.cod_ofi_origen) cod_oficina, v.nom_completo,
            v.nro_doc_persona nro_documento, p.tipo, v.nro_cuenta,
            v.nro_documento nro_recibo, v.rowid fila, v.aju_impuesto_5, v.aju_impuesto_10,
            decode(nvl(fue_per_dat_adicional(nvl(p_cod_persona,v.cod_persona),'TIP_FACTURACION'),'L'),'L','GS',v.cod_moneda) cod_mon_factura,
            v.can_cuota, v.cod_modulo,v.cod_modalidad,v.cod_transaccion, 'V' tip_operacion,p.tip_iva /*DYDMR-5605 NAF 03/2017*/
       from cb_lib_ventas_det_tmp v,  ge_clientes c, ba_personas p
      where nvl(v.reversado,'N') = 'N'
        and nvl(v.tip_comprobante,'X') = 'C'  -- CNFNORMA-18/RABP/10-2016: Debe incluir operaciones de cambio
        and c.cod_persona(+) =  v.cod_persona
        and p.cod_persona(+)  = v.cod_persona
        --- Verificar si tiene parámetros
        and ((v.cod_persona  = nvl(p_cod_persona,v.cod_persona)) or
             (v.cod_persona is null and p_cod_persona is null))
        and v.fecha        = nvl(p_fecha,v.fecha)
        and v.hora         = nvl(p_hora,v.hora)
        and v.error is null  -- solo tomas los que no tienen error
        and v.cod_usuario  = nvl(p_cod_usuario,v.cod_usuario)
    union all
    -- cursor c_compras
     select nvl(v.cod_persona,0)cod_persona, v.fecha, v.hora, v.cod_usuario, v.nro_secuencia, v.cod_ofi_origen,
            v.tip_comprobante, v.tip_compra tip_factura,
            v.cod_mod_padre, v.cod_mad_padre, v.cod_tra_padre,
            v.descripcion,
            v.cod_moneda, v.mto_exento, v.mto_exento_gs, v.mto_gravado_5, v.mto_gra_5_gs,
            v.mto_gravado_10, v.mto_gra_10_gs, v.impuesto_5, v.impuesto_5_gs,
            v.impuesto_10, v.impuesto_10_gs, v.cotizacion, nvl(c.cod_oficina,v.cod_ofi_origen) cod_oficina, v.nom_completo,
            v.nro_doc_persona nro_documento, p.tipo, v.nro_cuenta,
            v.nro_documento nro_recibo, v.rowid fila, v.aju_impuesto_5, v.aju_impuesto_10,
            decode(nvl(fue_per_dat_adicional(nvl(p_cod_persona,v.cod_persona),'TIP_FACTURACION'),'L'),'L','GS',v.cod_moneda) cod_mon_factura,
            v.can_cuota, v.cod_modulo,v.cod_modalidad,v.cod_transaccion, 'C' tip_operacion,p.tip_iva /*DYDMR-5605 NAF 03/2017*/
       from cb_lib_compras_det_tmp v,  ge_clientes c, ba_personas p
      where nvl(v.reversado,'N') = 'N'
        and nvl(v.tip_comprobante,'X') = 'C'  -- CNFNORMA-18/RABP/10-2016: Debe incluir operaciones de cambio
        and c.cod_persona(+) =  v.cod_persona
        and p.cod_persona(+)  = v.cod_persona
        --- Verificar si tiene parámetros
        and ((v.cod_persona  = nvl(p_cod_persona,v.cod_persona)) or
             (v.cod_persona is null and p_cod_persona is null))
        and v.fecha        = nvl(p_fecha,v.fecha)
        and v.hora         = nvl(p_hora,v.hora)
        and v.error is null  -- solo tomas los que no tienen error
        and v.cod_usuario  = nvl(p_cod_usuario,v.cod_usuario)
     order by nom_completo, cod_persona, cod_mon_factura, fecha, hora, tip_operacion;
   TYPE cursor1_type IS TABLE OF c_facturas%ROWTYPE;
                        reg cursor1_type;
BEGIN 
   -- Registrar el nombre en action
   DBMS_APPLICATION_INFO.SET_ACTION('PAB_IVA');
   DBMS_APPLICATION_INFO.SET_CLIENT_INFO('PR_GEN_FAC_CAMBIO, Iniciando');
   Begin pre_ini_aplicacion;pae_cnf.G_COD_MODULO:=1;end;
   v_cod_persona := '.';
   v_tip_venta   := '.';
   v_tip_compra  := '.';
   v_cod_mon_factura := '.';
   v_nro_lin_fac := 1;   -- esta es la cantidad de lineas por factura que se puede imprimir
   v_nro_linea   := 0;
   v_fec_proceso := pag_cal.fu_obt_fec_actual(1);
    OPEN c_facturas;
    LOOP
      FETCH c_facturas BULK COLLECT INTO reg LIMIT 2500;
      FOR i IN 1.. reg.count LOOP
      -- Monitoreo del avance cada 100 registros o al final
      IF MOD(i, 100) = 0 OR i = reg.COUNT THEN
          v_mensaje := 'PR_GEN_FAC_CAMBIO-registro ' || i || ' de ' || reg.COUNT;
          DBMS_APPLICATION_INFO.SET_CLIENT_INFO(v_mensaje);
      END IF;
      v_lugar := reg(i).cod_persona;
      --30/06/2010: No procesar los registros marcados
      --con tipo comprobante ='X', corresponden a Iva s/Interes vencido ya cobrado y facturado.
      If reg(i).tip_comprobante = 'X' then
        --Si es fin de mes borrar los registros con tipo comprobante ='X'
        if pag_cal.G_FEC_ACTUAL = pag_cal.G_ULT_DIA_MES_HABIL then
          delete cb_lib_ventas_det_tmp
           where rowid = reg(i).fila;
          v_borrado := 1;
        end if;
      else
        -- Factura Compra de Divisas --
        if reg(i).tip_operacion = 'C' then
          --- Corte de control --
          if nvl(v_cod_persona,'-1') <> nvl(reg(i).cod_persona,'-1')
          or nvl(v_tip_compra,'.') <> nvl(reg(i).tip_factura,'.')
          or nvl(v_cod_mon_factura,'.') <> nvl(reg(i).cod_mon_factura,'.')
          or v_nro_linea + 1 > v_nro_lin_fac then
             v_cod_oficina := reg(i).cod_oficina; -- Modificado 05/03/2010 por ICL - para que tome oficina del cliente
             --Si existe Oficina Generica
             IF v_ofi_pto_generico <> -1 THEN
               v_cod_oficina := v_ofi_pto_generico;
             END IF;
             v_pun_expedicion := fu_obt_pun_expedicion('A', v_cod_oficina);           
             --- Insertar cabecera para la factura --
             v_cod_ofi_hacienda :=fug_obt_pardinamico('COD_OFI_HACIENDA', null, null, null, v_cod_oficina);
             if v_cod_ofi_hacienda is null then
               raise_application_error(-20000, 'No se ha definido el parametro COD_OFI_HACIENDA para la oficina '||v_cod_oficina);
             end if;
             --v_pun_expedicion := fu_obt_pun_expedicion('A'); -- Punto de expedicion diferente para Compras --
             pab_iva.pr_obt_nro_factura(v_cod_oficina, v_fec_proceso, 'A', v_nro_factura, v_nro_tim_fac, v_fec_vig_tim);

             rv_blcom.nro_factura      := lpad(v_cod_ofi_hacienda,3,'0')||
                                              '-'||lpad(v_pun_expedicion,3,'0')||
                                              '-'||lpad(to_char(v_nro_factura),7,'0');
             v_nro_fac_retorno         := rv_blcom.nro_factura;
             rv_blcom.fecha            := v_fec_proceso;
             rv_blcom.tipo             := reg(i).tip_factura;
             if reg(i).cod_persona is not null then
               rv_blcom.cod_persona    := reg(i).cod_persona;
               rv_blcom.raz_social     := reg(i).nom_completo;
               rv_blcom.nro_documento  := reg(i).nro_documento;
             else
               rv_blcom.cod_persona    := null;
               rv_blcom.raz_social     := 'SIN NOMBRE';
               rv_blcom.nro_documento  := 'X';
             end if;
             rv_blcom.mto_exento       := reg(i).mto_exento_gs;
             rv_blcom.mto_gravado_10   := reg(i).mto_gravado_10;
             rv_blcom.impuesto_10      := reg(i).impuesto_10;
             rv_blcom.mto_gravado_5    := reg(i).mto_gravado_5;
             rv_blcom.impuesto_5       := reg(i).impuesto_5;
             rv_blcom.nro_timbrado     := v_nro_tim_fac;
             rv_blcom.cod_ofi_origen   := reg(i).cod_ofi_origen;
             rv_blcom.cod_ent_proveedor:= 999;
             rv_blcom.fec_pago         := v_fec_proceso;
             rv_blcom.can_cuota        := 0;  -- Cuota cero porque siempre es contado en Operacion de Cambio
             rv_blcom.tip_origen       := reg(i).tip_comprobante;
             --- Insertamos datos cabecera ---
             prb_ins_lib_compras(rv_blcom);


             --- Insertar detalle para la factura --
             rv_blcde.nro_factura        := rv_blcom.nro_factura;
             rv_blcde.cod_persona        := rv_blcom.cod_persona;
             rv_blcde.nro_timbrado       := rv_blcom.nro_timbrado;
             rv_blcde.fecha              := rv_blcom.fecha;
             rv_blcde.hora               := reg(i).hora;
             rv_blcde.cod_usuario        := reg(i).cod_usuario;
             rv_blcde.nro_secuencia      := reg(i).nro_secuencia;
             rv_blcde.cod_oficina        := reg(i).cod_oficina;
             rv_blcde.cod_moneda         := reg(i).cod_mon_factura;
             rv_blcde.mto_operacion_me   := reg(i).mto_exento;
             rv_blcde.cotizacion         := reg(i).cotizacion;
             rv_blcde.cod_mon_operacion  := reg(i).cod_moneda;
             rv_blcde.fec_vig_timbrado   := v_fec_vig_tim;
             rv_blcde.cod_mod_padre      := reg(i).cod_mod_padre;
             rv_blcde.cod_mad_padre      := reg(i).cod_mad_padre;
             rv_blcde.cod_modulo         := reg(i).cod_modulo;
             rv_blcde.cod_modalidad      := reg(i).cod_modalidad;
             rv_blcde.cod_tra_padre      := reg(i).cod_tra_padre;
             rv_blcde.cod_transaccion    := reg(i).cod_transaccion;
             rv_blcde.tip_comprobante    := 'F';
             rv_blcde.nro_cuenta         := reg(i).nro_cuenta;
             --- Insertamos datos detalle ---
             pab_iva.PR_INS_LIB_COM_DET(rv_blcde);

              --- Eliminar notas de creditos temporales
              delete cb_lib_compras_det_tmp
               where rowid = reg(i).fila;
            end if;
        end if; -- fin factura compra

        -- Factura Venta de Divisas --
        if reg(i).tip_operacion = 'V' then
          --- Corte de control --
          if nvl(v_cod_persona,'-1') <> nvl(reg(i).cod_persona,'-1')
          or nvl(v_tip_venta,'.') <> nvl(reg(i).tip_factura,'.')
          or nvl(v_cod_mon_factura,'.') <> nvl(reg(i).cod_mon_factura,'.')
          or v_nro_linea + 1 > v_nro_lin_fac then
             
             v_cod_oficina := reg(i).cod_oficina; -- Modificado 05/03/2010 por ICL - para que tome oficina del cliente
             v_pun_expedicion := fu_obt_pun_expedicion(reg(i).tip_comprobante, v_cod_oficina);
             if v_ofi_pto_generico <> -1 then
               v_cod_oficina := v_ofi_pto_generico;
             end if; 
             --- Insertar cabecera para la factura
             v_cod_ofi_hacienda :=fug_obt_pardinamico('COD_OFI_HACIENDA', null, null, null, v_cod_oficina);
             if v_cod_ofi_hacienda is null then
               raise_application_error(-20000, 'No se ha definido el parametro COD_OFI_HACIENDA para la oficina '||v_cod_oficina);
             end if;

             --v_pun_expedicion := fu_obt_pun_expedicion(reg.tip_comprobante);
             pab_iva.pr_obt_nro_factura(v_cod_oficina, v_fec_proceso, reg(i).tip_comprobante, v_nro_factura, v_nro_tim_fac, v_fec_vig_tim);

             begin
               select fec_ini_timbrado
                 into v_fec_aut_timbrado
                 from cb_par_comprobantes a
                where nro_timbrado = v_nro_tim_fac
                  and tipo = reg(i).tip_comprobante
                  and cod_oficina = v_cod_oficina;
             exception
               when no_data_found then
                 raise_application_error(-20000,'No se ha encontrado fecha de inicio de timbrado
                                                 para la ofic. '||v_cod_oficina||' Tip. compr.'
                                                 ||reg(i).tip_comprobante||' .' ||sqlerrm);
               when others then
                 raise_application_error(-20000,v_lugar||sqlerrm);
             end;
             --- Insertar cabecera
             rv_blven.nro_factura        := lpad(v_cod_ofi_hacienda,3,'0')||
                                              '-'||lpad(v_pun_expedicion,3,'0')||
                                              '-'||lpad(to_char(v_nro_factura),7,'0');
             v_nro_fac_retorno           := rv_blven.nro_factura;
             rv_blven.nro_timbrado       := v_nro_tim_fac;
             rv_blven.fec_vig_timbrado   := v_fec_vig_tim;
             rv_blven.fecha              := reg(i).fecha;--v_fec_proceso;
             rv_blven.cod_oficina        := v_cod_oficina;
             rv_blven.tip_comprobante    := 'F';
             rv_blven.tip_venta          := reg(i).tip_factura;
             rv_blven.fec_aut_timbrado   := v_fec_aut_timbrado;
             if reg(i).cod_persona is not null then
               rv_blven.cod_persona      := reg(i).cod_persona;
               rv_blven.nom_completo     := reg(i).nom_completo;
               rv_blven.nro_documento    := reg(i).nro_documento;
               rv_blven.dig_verificador  := null;
               if reg(i).tipo = 'J' then
                 begin
                   if instr(reg(i).nro_documento,'-') > 0 then
                     rv_blven.nro_documento   := substr(reg(i).nro_documento,1,instr(reg(i).nro_documento,'-')-1);
                     rv_blven.dig_verificador := substr(reg(i).nro_documento,-1);
                   end if;
                 exception
                    when others then
                       rv_blven.nro_documento := reg(i).nro_documento;
                       rv_blven.dig_verificador := NULL;
                 end;
               else
                 begin
                   if instr(reg(i).nro_documento,'-') > 0 then
                      rv_blven.nro_documento   := substr(reg(i).nro_documento,1,instr(reg(i).nro_documento,'-')-1);
                      rv_blven.dig_verificador := substr(reg(i).nro_documento,-1);
                   else
                      -- DYDMR-5605 NAF 03/2017 Si el cliente es no contribuyente dig_verificador es NULL
                      if reg(i).tip_iva = 'NC' then
                        rv_blven.dig_verificador := NULL;
                      else
                        rv_blven.dig_verificador := fue_obt_ruc_dig_verificador(reg(i).nro_documento);
                      end if;
                   end if;
                 exception
                    when others then
                       rv_blven.nro_documento := reg(i).nro_documento;
                       rv_blven.dig_verificador := NULL;
                 end;
               end if;
               rv_blven.direccion        := fue_obt_dir_principa(reg(i).cod_persona);
               rv_blven.telefono         := fue_obt_tel_principa(reg(i).cod_persona);
               if rv_blven.nro_documento is null then
                 rv_blven.nro_documento  := reg(i).nro_documento;
               end if;
             else
               rv_blven.cod_persona      := null;
               rv_blven.nom_completo     := 'SIN NOMBRE';
               rv_blven.nro_documento    := 'X';
               rv_blven.dig_verificador  := null;
               rv_blven.direccion        := null;
               rv_blven.telefono         := null;
             end if;
             rv_blven.cod_moneda         := reg(i).cod_mon_factura;
             rv_blven.can_cuota          := 0;
             rv_blven.tip_origen         := reg(i).tip_comprobante;
             rv_blven.serie              := IT.FUG_OBT_SERIE(nvl(reg(i).tip_comprobante, 'F'),
                                                             v_cod_oficina,
                                                             v_nro_tim_fac);
             pab_iva.PR_INS_LIB_VEN_CAB(rv_blven);
             --- Obs. Los totales de la cabecera son por trigger
             v_nro_linea   := 0;
             v_cod_persona := reg(i).cod_persona;
             v_tip_venta   := reg(i).tip_factura;
             v_cod_mon_factura := reg(i).cod_mon_factura;
             v_max_cuota := 0;
             v_tip_comprobante := reg(i).tip_comprobante;
          end if;
          -- verificar la mayor cuota y actualizar cb_lib_ventas. CNF 16/03/15
          v_auxiliar := reg(i).can_cuota;
          if v_auxiliar > v_max_cuota then
             v_max_cuota := v_auxiliar;
             update cb_lib_ventas c
                set c.can_cuota = v_max_cuota
              where c.nro_factura  = rv_blven.nro_factura
                and c.nro_timbrado = rv_blven.nro_timbrado;
          end if;
             v_auxiliar := 0;
          --
          v_nro_linea             := v_nro_linea + 1;
          --- Insertar detalles
          rv_blvde.fecha          := reg(i).fecha;
          rv_blvde.hora           := reg(i).hora;
          rv_blvde.cod_usuario    := reg(i).cod_usuario;
          rv_blvde.nro_secuencia  := reg(i).nro_secuencia;
          rv_blvde.nro_factura    := rv_blven.nro_factura;
          rv_blvde.nro_timbrado   := rv_blven.nro_timbrado;
          rv_blvde.cod_ofi_origen := reg(i).cod_ofi_origen;
          rv_blvde.cod_mod_padre  := reg(i).cod_mod_padre;
          rv_blvde.cod_mad_padre  := reg(i).cod_mad_padre;
          rv_blvde.cod_tra_padre  := reg(i).cod_tra_padre;
          rv_blvde.nro_documento  := reg(i).nro_recibo;
          rv_blvde.descripcion    := reg(i).descripcion;
          rv_blvde.cod_moneda     := reg(i).cod_moneda;
          rv_blvde.mto_exento     := reg(i).mto_exento;
          rv_blvde.mto_exento_gs  := reg(i).mto_exento_gs;
          rv_blvde.mto_gravado_5  := reg(i).mto_gravado_5;
          rv_blvde.mto_gra_5_gs   := reg(i).mto_gra_5_gs;
          rv_blvde.mto_gravado_10 := reg(i).mto_gravado_10;
          rv_blvde.mto_gra_10_gs  := reg(i).mto_gra_10_gs;
          rv_blvde.impuesto_5     := reg(i).impuesto_5;
          rv_blvde.impuesto_5_gs  := reg(i).impuesto_5_gs;
          rv_blvde.impuesto_10    := reg(i).impuesto_10;
          rv_blvde.impuesto_10_gs := reg(i).impuesto_10_gs;
          rv_blvde.cotizacion     := reg(i).cotizacion;
          rv_blvde.nro_cuenta     := reg(i).nro_cuenta;
          rv_blvde.aju_impuesto_5 := reg(i).aju_impuesto_5;
          rv_blvde.aju_impuesto_10:= reg(i).aju_impuesto_10;
          --Transac. Mod. Moda.
          rv_blvde.cod_modulo:= reg(i).cod_modulo;
          rv_blvde.cod_modalidad:= reg(i).cod_modalidad;
          rv_blvde.cod_transaccion:= reg(i).cod_transaccion;
          rv_blvde.tip_comprobante := 'F';
          pab_iva.PR_INS_LIB_VEN_DET(rv_blvde);
          --- Eliminar notas de creditos temporales
          delete cb_lib_ventas_det_tmp
            where rowid = reg(i).fila;
            v_borrado := 1;
        end if; -- fin factura venta

     End if;
     end loop;
     EXIT WHEN c_facturas%NOTFOUND;
   END LOOP;
   close c_facturas;
   IF v_borrado <> 0 THEN
         DELETE cb_lib_ventas_tmp
          WHERE cod_persona = p_cod_persona
            AND reversado = 'N'
            AND (fecha = p_fecha OR p_fecha is null)
            AND (hora = p_hora or p_hora is null)
            AND (cod_usuario = p_cod_usuario or p_cod_usuario is null);
   END IF;  
   -- Dejar null la acción para que no quede en memoria 
   DBMS_APPLICATION_INFO.SET_ACTION(NULL);
   DBMS_APPLICATION_INFO.SET_CLIENT_INFO(NULL); 
exception
   when others then
     -- Dejar null la acción para que no quede en memoria 
     DBMS_APPLICATION_INFO.SET_ACTION(NULL);
     DBMS_APPLICATION_INFO.SET_CLIENT_INFO(NULL); 
     raise_application_error(-20033,v_lugar||sqlerrm);
END;

/* Insertar detalle del Libro Compra */
PROCEDURE PR_INS_LIB_COM_DET
 (RP_BLCDE IN CB_LIB_COMPRAS_DET%ROWTYPE
 )
 IS
 v_fec_ini_timbrado   cb_lib_ventas.fec_ini_timbrado%type;
 v_nro_aut_timbrado   cb_lib_ventas.nro_aut_timbrado%type;
begin
   --CNFNORMA-18 - CNF - RABP - 10/2016 - Se agrega la insercion de los 2 nuevos campos de cb_lib_compras
   begin
     select fec_ini_timbrado, nro_aut_timbrado
       into v_fec_ini_timbrado, v_nro_aut_timbrado
       from cb_par_comprobantes
      where nro_timbrado = RP_BLCDE.nro_timbrado
        and tipo = RP_BLCDE.tip_comprobante;
    exception
       when others then
          raise_application_error(-20000,'Error en obtener datos. '||Sqlerrm);
    end;


   insert into cb_lib_compras_det(
      nro_factura, cod_persona, nro_timbrado, fecha, hora, cod_usuario, nro_secuencia,
      cod_oficina, cod_moneda, mto_operacion_me, cotizacion, cod_mon_operacion, fec_ini_timbrado,
      fec_vig_timbrado, nro_aut_timbrado, cod_mod_padre, cod_mad_padre, cod_modulo, cod_modalidad,
      cod_tra_padre, cod_transaccion, tip_comprobante, nro_cuenta)
   values(
      rp_blcde.nro_factura, rp_blcde.cod_persona, rp_blcde.nro_timbrado, rp_blcde.fecha,
      rp_blcde.hora, rp_blcde.cod_usuario, rp_blcde.nro_secuencia, rp_blcde.cod_oficina,
      rp_blcde.cod_moneda, rp_blcde.mto_operacion_me, rp_blcde.cotizacion, rp_blcde.cod_mon_operacion,
      v_fec_ini_timbrado, rp_blcde.fec_vig_timbrado, v_nro_aut_timbrado, rp_blcde.cod_mod_padre,
      rp_blcde.cod_mad_padre, rp_blcde.cod_modulo, rp_blcde.cod_modalidad,
      rp_blcde.cod_tra_padre, rp_blcde.cod_transaccion, rp_blcde.tip_comprobante, rp_blcde.nro_cuenta)    ;
end;

 /* Genera libro venta y compra de las operaciones de cambios, retorna nro de factura */
FUNCTION FU_GEN_FAC_CAMBIO
 (P_COD_PERSONA IN VARCHAR2
 ,P_FECHA IN DATE default null
 ,P_HORA IN varchar2 default null
 ,P_COD_USUARIO IN VARCHAR2 default null
 )
 RETURN VARCHAR2 IS
BEGIN
 PR_GEN_FAC_CAMBIO(P_COD_PERSONA, P_FECHA, P_HORA,P_COD_USUARIO);
 RETURN v_nro_fac_retorno;
END;

/* Genera compra por INR, retorna nro de factura */
FUNCTION FU_GEN_FAC_INR
 (P_COD_PERSONA IN VARCHAR2
 ,P_FECHA IN DATE default null)
 RETURN VARCHAR2 IS
 v_nro_fac_generado       cb_lib_compras.nro_factura%type;
BEGIN
 PRA_GEN_FAC_INR(P_FECHA, P_COD_PERSONA,null, v_nro_fac_generado);
 v_nro_fac_retorno := (v_nro_fac_generado);
 RETURN v_nro_fac_retorno;
END;
  
END PAB_IVA;
/
