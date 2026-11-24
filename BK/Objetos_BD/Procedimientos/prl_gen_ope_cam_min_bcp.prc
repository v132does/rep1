create or replace procedure it.prl_gen_ope_cam_min_bcp(p_fecha in date) is

  ---Proyecto SDOPECAM-1 Generacion datos Operaciones de Cambios diario-----
  --Operaciones de Cambios Minorista (Codificado) - Resolucion 107/ 2019--

  PRAGMA AUTONOMOUS_TRANSACTION;
  v_fecha date;
  v_bcp_mto_inf_cambios LC_OPE_CAM_MIN_BCP_TMP.Monto%type;
  v_exi_datos varchar2(1);
  v_mensaje_error varchar2(100) default null;
  v_cod_per_entidad ba_personas.cod_persona%TYPE := fue_obt_per_ente(fug_obt_cod_entidad);

  --Operaciones de arbitraje a ajustar--
  cursor c_ope_ajustar is

    select --Tipo Operacion de Cambio--
           case
             when t.cod_tip_operacion = '442' then '292'
             when t.cod_tip_operacion = '443' then '293'
             when t.cod_tip_operacion = '61' then '16'
           else null end cod_tip_ope_aju,
           t.rowid registro,

           --Mercado BCP--
           case when ((t.com_moneda <> 'USD') or (t.vta_moneda <> 'USD')) then 7 --OP.NO'
           else 1 ---SPOT'
           end mer_aju,

           --Tipo de Operacion BCP--
           case
             when t.cod_tip_operacion in ('442','443') then 1 --VENTA'
             when t.cod_tip_operacion = 61 then 0 --COMPRA'
           else null end tip_ope_aju,
           X.DESCRIPCION des_tip_ope_aju
      from LC_OPE_CAM_MIN_BCP_DET t, LC_TIP_OPERACIONES x
     where T.COD_TIP_OPE_CONTRA IS NULL
       and T.TIP_OPERACION = 3 --ARBITRAJE'
       and X.COD_TIP_OPERACION = (case when t.cod_tip_operacion = '442' then '292'
                                       when t.cod_tip_operacion = '443' then '293'
                                       when t.cod_tip_operacion = '61' then '16'
                                       else t.cod_tip_operacion end);

  procedure lp_act_dat_inconsistentes is
  --Datos inconsistentes para generar codigos correctos--
  begin
    for det in c_ope_ajustar loop
          update LC_OPE_CAM_MIN_BCP_DET t
             set t.cod_tip_operacion = det.cod_tip_ope_aju,
                 t.mercado = det.mer_aju,
                 t.tip_operacion = det.tip_ope_aju,
                 t.des_tip_operacion = det.des_tip_ope_aju
           where t.rowid = det.registro;
      end loop;
  end;

  procedure lp_act_cod_tip_ope_contra is
  --Actualizar el tipo de operacion de cambios de contrapartida--
  begin
    --Compras y Ventas con la secuencia 3---
    update LC_OPE_CAM_MIN_BCP_DET x
       set (x.cod_tip_ope_contra, x.des_tip_ope_contra) =
                                    (select Y.COD_TIP_OPE_CAMBIO, z.descripcion
                                       from LC_OPE_CAM_MIN_BCP_TMP y, lc_tip_operaciones z
                                      where y.fecha = x.fecha
                                        and y.hora = x.hora
                                        and y.cod_usuario = x.cod_usuario
                                        and y.nro_secuencia = 3
                                        and y.cod_moneda = 'GS'
                                        and z.cod_tip_operacion = y.cod_tip_ope_cambio)
      WHERE x.cod_mad_padre in (71,72)
        and x.cod_tip_ope_contra is null
        and exists (select 1
                      from LC_OPE_CAM_MIN_BCP_TMP y, lc_tip_operaciones z
                                      where y.fecha = x.fecha
                                        and y.hora = x.hora
                                        and y.cod_usuario = x.cod_usuario
                                        and y.nro_secuencia = 3
                                        and y.cod_moneda = 'GS'
                                        and z.cod_tip_operacion = y.cod_tip_ope_cambio);

  --Compra - Conf.Transferencias Recibidas  - Crédito Cta--
  update LC_OPE_CAM_MIN_BCP_DET x
   set (x.cod_tip_ope_contra, x.des_tip_ope_contra) =
                              (select 'X1', y.concepto||'-'||y.cod_moneda
                                 from LC_OPE_CAM_MIN_BCP_TMP y
                                where y.fecha = x.fecha
                                  and y.hora = x.hora
                                  and y.cod_usuario = x.cod_usuario
                                  and y.concepto = 'Conf.Transf.-Crédito Cta'
                                  and y.cod_moneda = 'GS')
  WHERE x.cod_mad_padre = 71
    and x.cod_tip_ope_contra is null
    and exists (select 1
                  from LC_OPE_CAM_MIN_BCP_TMP y
                                  where y.fecha = x.fecha
                                    and y.hora = x.hora
                                    and y.cod_usuario = x.cod_usuario
                                    and y.concepto = 'Conf.Transf.-Crédito Cta'
                                    and y.cod_moneda = 'GS');

  update LC_OPE_CAM_MIN_BCP_DET x
   set (x.cod_tip_ope_contra, x.des_tip_ope_contra) =
                              (select 'X1', y.concepto||'-'||y.cod_moneda
                                 from LC_OPE_CAM_MIN_BCP_TMP y
                                where y.fecha = x.fecha
                                  and y.hora = x.hora
                                  and y.cod_usuario = x.cod_usuario
                                  and y.concepto = 'Operación de Cambios-Créd. Ctble'
                                  and y.cod_moneda = 'GS')
  WHERE x.cod_mad_padre = 71
    and x.cod_tip_ope_contra is null
    and exists (select 1
                  from LC_OPE_CAM_MIN_BCP_TMP y
                                  where y.fecha = x.fecha
                                    and y.hora = x.hora
                                    and y.cod_usuario = x.cod_usuario
                                    and y.concepto = 'Operación de Cambios-Créd. Ctble'
                                    and y.cod_moneda = 'GS');

  update LC_OPE_CAM_MIN_BCP_DET x
   set (x.cod_tip_ope_contra, x.des_tip_ope_contra) =
                              (select 'X1', substr(y.concepto,1,20)||'-'||y.cod_moneda
                                 from LC_OPE_CAM_MIN_BCP_TMP y
                                where y.fecha = x.fecha
                                  and y.hora = x.hora
                                  and y.cod_usuario = x.cod_usuario
                                  and substr(y.concepto,1,20) = 'Operación de Cambios'
                                  and y.nro_cuenta is not null
                                  and y.cod_moneda = 'GS')
  WHERE x.cod_mad_padre = 71
    and x.cod_tip_ope_contra is null
    and exists (select 1
                  from LC_OPE_CAM_MIN_BCP_TMP y
                                  where y.fecha = x.fecha
                                    and y.hora = x.hora
                                    and y.cod_usuario = x.cod_usuario
                                    and substr(y.concepto,1,20) = 'Operación de Cambios'
                                    and y.nro_cuenta is not null
                                    and y.cod_moneda = 'GS');

  --Venta / Debitos en cuenta--
  update LC_OPE_CAM_MIN_BCP_DET x
     set (x.cod_tip_ope_contra, x.des_tip_ope_contra) = (select 'X2', 'Débito Cta-GS'
                                   from LC_OPE_CAM_MIN_BCP_TMP y
                                  where y.fecha = x.fecha
                                    and y.hora = x.hora
                                    and y.cod_usuario = x.cod_usuario
                                    and y.concepto = 'Operación de Cambios-Débito Cta'
                                    and y.cod_moneda = 'GS'
                                    and y.cod_moneda <> x.vta_moneda)
  WHERE x.cod_mad_padre = 72
    and x.cod_tip_ope_contra is null
    and exists (select 1
                  from LC_OPE_CAM_MIN_BCP_TMP y
                                  where y.fecha = x.fecha
                                    and y.hora = x.hora
                                    and y.cod_usuario = x.cod_usuario
                                    and y.concepto = 'Operación de Cambios-Débito Cta'
                                    and y.cod_moneda = 'GS'
                                    and y.cod_moneda <> x.vta_moneda);

  --Venta / Debitos en cuenta--
  update LC_OPE_CAM_MIN_BCP_DET x
     set (x.cod_tip_ope_contra, x.des_tip_ope_contra) = (select 'X3', 'Débito Cta-GS'
                                                           from LC_OPE_CAM_MIN_BCP_TMP y
                                                          where y.fecha = x.fecha
                                                            and y.hora = x.hora
                                                            and y.cod_usuario = x.cod_usuario
                                                            and SUBSTR(y.concepto,1,20) = 'Operación de Cambios'
                                                            and y.cod_moneda = 'GS'
                                                            and y.cod_moneda <> x.vta_moneda)
  WHERE x.cod_mad_padre = 72
    and x.cod_tip_ope_contra is null
    and exists (select 1
                  from LC_OPE_CAM_MIN_BCP_TMP y
                                  where y.fecha = x.fecha
                                    and y.hora = x.hora
                                    and y.cod_usuario = x.cod_usuario
                                    and SUBSTR(y.concepto,1,20) = 'Operación de Cambios'
                                    and y.cod_moneda = 'GS'
                                    and y.cod_moneda <> x.vta_moneda);

  --Venta / Debitos en cuenta--
  update LC_OPE_CAM_MIN_BCP_DET x
     set x.cod_tip_ope_contra = 'X4',
         x.des_tip_ope_contra = 'Operación de Cambios-Débito Cta'
   WHERE x.cod_mad_padre = 72
     and x.cod_tip_ope_contra is null
     and x.cod_tip_operacion in ('29','292','293');

  ---Compra y Venta de Cuenta Contable ----
  update LC_OPE_CAM_MIN_BCP_DET x
     set x.cod_tip_ope_contra = decode(cod_mad_padre,71,'X5','X6'),         
         x.des_tip_ope_contra = decode(x.cod_persona,v_cod_per_entidad,'Operacion Interna Banco','Operación Interna Clientes')
   WHERE x.cod_mad_padre in (71,72)
     and x.cod_tip_ope_contra is null
     and x.cod_tip_operacion in ('17','31');


 --Venta / Debitos en cuenta--
  update LC_OPE_CAM_MIN_BCP_DET x
     set (x.cod_tip_ope_contra, x.des_tip_ope_contra) = (select 'X7', 'Cobro Efectivo GS'
                                                           from LC_OPE_CAM_MIN_BCP_TMP y
                                                          where y.fecha = x.fecha
                                                            and y.hora = x.hora
                                                            and y.cod_usuario = x.cod_usuario
                                                            and y.concepto = 'Operacion de Cambios Caja'
                                                            and y.cod_moneda = 'GS'
                                                            and y.cod_moneda <> x.vta_moneda)
  WHERE x.cod_mad_padre = 72
    and x.cod_tip_ope_contra is null
    and exists (select 1
                  from LC_OPE_CAM_MIN_BCP_TMP y
                                  where y.fecha = x.fecha
                                    and y.hora = x.hora
                                    and y.cod_usuario = x.cod_usuario
                                    and y.concepto = 'Operacion de Cambios Caja'
                                    and y.cod_moneda = 'GS'
                                    and y.cod_moneda <> x.vta_moneda);

  --Codigo generico si no tiene--
  update LC_OPE_CAM_MIN_BCP_DET x
     set x.cod_tip_ope_contra = 'X8',
         x.des_tip_ope_contra = 'Sin descripcion'
   WHERE x.cod_mad_padre in (71,72,73)
     and x.cod_tip_ope_contra is null;

  end;

  procedure lp_act_tip_can_env_bcp is
  begin
    --Actualizar Tipo de Canje BCP--
    update LC_OPE_CAM_MIN_BCP_DET k
       set (k.tip_canje, k.ref_canje) = (select z.abreviatura,
                                                k.cod_mad_padre||'.'||k.cod_tip_operacion||'.'||k.cod_tip_ope_contra
                                           from ba_cod_referencias z
                                          where z.val_minimo = k.cod_mad_padre||'.'||k.cod_tip_operacion||'.'||k.cod_tip_ope_contra)
     where k.tip_canje is null
       and k.cod_mad_padre = 74 --Solo los canjes deben tener tipo de canje--
       and exists (select 1
                     from ba_cod_referencias z
                    where z.val_minimo = k.cod_mad_padre||'.'||k.cod_tip_operacion||'.'||k.cod_tip_ope_contra);

    --Actualizar Ciudad BCP--
    update LC_OPE_CAM_MIN_BCP_DET k
       set k.ciudad = fug_obt_pardinamico('COD_CIU_RCF_BCP', null, null, null, 7, null)
     where k.ciudad is null;

    --Actualizar a no enviar Operaciones menores o iguales a USD 1 (Regla de Negocio de BCP)--
    /*update LC_OPE_CAM_MIN_BCP_DET k
       set k.env_bcp = 'N'
     where ((k.com_moneda is not null and nvl(k.com_mto_usd,0) <= 1) or
            (k.vta_moneda is not null and nvl(k.vta_mto_usd,0) <= 1))
       and k.env_bcp = 'S';*/
  end;

  procedure lp_act_uni_ope_arbitraje is
  begin
    --Actualizar Ventas--
    update LC_OPE_CAM_MIN_BCP_DET t
       set (vta_moneda, vta_monto, vta_precio, vta_mto_usd, tot_equ_venta, nro_cta_contra)=
             (select vta_moneda, vta_monto, vta_precio, vta_mto_usd, tot_equ_venta,
                     decode(t.nro_cta_contra,null,x.nro_cta_contra,t.nro_cta_contra)
                from lc_ope_cam_min_bcp_det x
               where x.cod_mad_padre = t.cod_mad_padre
                 and x.nro_secuencia = 2
                 and x.vta_moneda is not null
                 and x.nro_doc_ope = t.nro_doc_ope
                 and x.cod_persona = t.cod_persona)
     where t.cod_mad_padre = 73
       and t.nro_secuencia = 1
       and t.com_moneda is not null --Secuencia 1 es Compra--
       and exists (select 1
                     from LC_OPE_CAM_MIN_BCP_DET x
                    where x.cod_mad_padre = t.cod_mad_padre
                      and x.nro_secuencia = 2
                      and x.vta_moneda is not null
                      and x.nro_doc_ope = t.nro_doc_ope
                      and x.cod_persona = t.cod_persona);

    --Actualizar Compras--
    update LC_OPE_CAM_MIN_BCP_DET t
       set (com_moneda, com_monto, com_precio, com_mto_usd, tot_equ_compra, nro_cta_contra)=
             (select com_moneda, com_monto, com_precio, com_mto_usd, tot_equ_compra,
                     decode(t.nro_cta_contra,null,x.nro_cta_contra,t.nro_cta_contra)
                from lc_ope_cam_min_bcp_det x
               where x.cod_mad_padre = t.cod_mad_padre
                 and x.nro_secuencia = 2
                 and x.com_moneda is not null
                 and x.nro_doc_ope = t.nro_doc_ope
                 and x.cod_persona = t.cod_persona)
     where t.cod_mad_padre = 73
       and t.nro_secuencia = 1
       and t.vta_moneda is not null --Secuencia 1 es Venta--
       and exists (select 1
                     from LC_OPE_CAM_MIN_BCP_DET x
                    where x.cod_mad_padre = t.cod_mad_padre
                      and x.nro_secuencia = 2
                      and x.com_moneda is not null
                      and x.nro_doc_ope = t.nro_doc_ope
                      and x.cod_persona = t.cod_persona);

    --Eliminar secuencia2 de Arbitraje--
    delete from LC_OPE_CAM_MIN_BCP_DET t
     where t.cod_mad_padre = 73
       and t.nro_secuencia = 2;
  end;

  procedure lp_gen_nro_reg_env_bcp is

  begin
    update LC_OPE_CAM_MIN_BCP_DET y
       set y.nro_registro = rownum
     where y.env_bcp = 'S';
  end;

begin

  --Validacion de fecha--
  if p_fecha is null then
     v_mensaje_error := 'Ingrese fecha para informe.';
  end if;

  --Carga de Variables--
  v_fecha := p_fecha;
  v_bcp_mto_inf_cambios := fug_obt_pardinamico('BCP_MTO_INF_CAMBIOS');

  --Limpiar la tabla--
  delete from LC_OPE_CAM_MIN_BCP_TMP;
  delete from LC_OPE_CAM_MIN_BCP_DET;

      --Insertar los movimeintos del historico de cambios--
      INSERT INTO LC_OPE_CAM_MIN_BCP_TMP
      (fecha, hora, cod_usuario, nro_secuencia, fec_valor, monto,
              nro_cuenta, cod_moneda, cod_oficina, cod_error,
              cod_retencion, fec_fin_retencion, est_cuenta, estado,
              cod_causa, cod_banco, cod_ofi_origen, concepto,
              cod_tasa, val_tasa, cod_rubro, cod_ref_cambio,
              reversado, cod_usu_reversion, hor_reversion, emi_aviso,
              cod_tra_padre, cod_mod_padre, cod_mad_padre, cod_transaccion,
              cod_modulo, cod_modalidad, mto_equ_local, nro_caja,
              cotizacion, cod_bco_central, nro_documento, nro_documento2,
              nro_documento3, nro_documento4, protegido, cod_autorizacion,
              cod_usu_autorizador, tip_mov_rubro, cod_tip_ope_cambio, referencia,
              cod_persona, cod_sit_contable
      )
      SELECT fecha, hora, cod_usuario, nro_secuencia, fec_valor, monto,
              nro_cuenta, cod_moneda, cod_oficina, cod_error,
              cod_retencion, fec_fin_retencion, est_cuenta, estado,
              cod_causa, cod_banco, cod_ofi_origen, concepto,
              cod_tasa, val_tasa, cod_rubro, cod_ref_cambio,
              reversado, cod_usu_reversion, hor_reversion, emi_aviso,
              cod_tra_padre, cod_mod_padre, cod_mad_padre, cod_transaccion,
              cod_modulo, cod_modalidad, mto_equ_local, nro_caja,
              cotizacion, cod_bco_central, nro_documento, nro_documento2,
              nro_documento3, nro_documento4, protegido, cod_autorizacion,
              cod_usu_autorizador, tip_mov_rubro, cod_tip_ope_cambio, referencia,
              cod_persona, cod_sit_contable
              FROM LC_MOVIMIENTOS_HIS A
              WHERE A.FECHA = v_fecha;

      select decode(nvl(count(*),0),0,'N','S')
        into v_exi_datos
        from LC_OPE_CAM_MIN_BCP_TMP
       where rownum < 2;

      if v_exi_datos = 'N' then
         v_mensaje_error := 'Sin datos de Cambios p/ fecha '||to_char(v_fecha,'dd/mm/yyyy')||'. Verifique.';
      end if;

      --Insertar movimientos complementarios de ahorro vista--
      INSERT INTO LC_OPE_CAM_MIN_BCP_TMP
      (fecha, hora, cod_usuario, nro_secuencia, fec_valor, monto,
              nro_cuenta, cod_moneda, cod_oficina, cod_error,
              cod_retencion, fec_fin_retencion, est_cuenta, estado,
              cod_causa, cod_banco, cod_ofi_origen, concepto,
              cod_tasa, val_tasa, cod_rubro, cod_ref_cambio,
              reversado, cod_usu_reversion, hor_reversion, emi_aviso,
              cod_tra_padre, cod_mod_padre, cod_mad_padre, cod_transaccion,
              cod_modulo, cod_modalidad, mto_equ_local, nro_caja,
              cotizacion, cod_bco_central, nro_documento, nro_documento2,
              nro_documento3, nro_documento4, protegido, cod_autorizacion,
              cod_usu_autorizador, tip_mov_rubro, cod_tip_ope_cambio, referencia,
              cod_persona, cod_sit_contable
      )
      SELECT fecha, hora, cod_usuario, nro_secuencia, fec_valor, monto,
              nro_cuenta, cod_moneda, cod_oficina, cod_error,
              cod_retencion, fec_fin_retencion, est_cuenta, estado,
              cod_causa, cod_banco, cod_ofi_origen, concepto,
              cod_tasa, val_tasa, cod_rubro, cod_ref_cambio,
              reversado, cod_usu_reversion, hor_reversion, emi_aviso,
              cod_tra_padre, cod_mod_padre, cod_mad_padre, cod_transaccion,
              cod_modulo, cod_modalidad, mto_equ_local, nro_caja,
              cotizacion, cod_bco_central, nro_documento, nro_documento2,
              nro_documento3, nro_documento4, protegido, cod_autorizacion,
              cod_usu_autorizador, tip_mov_rubro, cod_tip_ope_cambio, referencia,
              cod_persona, cod_sit_contable
              FROM AH_MOVIMIENTOS_HIS A
              WHERE A.FECHA = v_fecha
                AND EXISTS (SELECT 1
                              FROM LC_OPE_CAM_MIN_BCP_TMP X
                             WHERE X.FECHA = A.FECHA
                               AND X.HORA = A.HORA
                               AND X.COD_USUARIO = A.COD_USUARIO)
                and not exists (select 1
                                  from LC_OPE_CAM_MIN_BCP_TMP z
                                 where z.fecha = a.fecha
                                   and z.hora = a.hora
                                   and z.cod_usuario = a.cod_usuario
                                   and z.nro_secuencia = a.nro_secuencia);

      --Insertar movimientos complementarios de cuentas corrientes--
      INSERT INTO LC_OPE_CAM_MIN_BCP_TMP
      (fecha, hora, cod_usuario, nro_secuencia, fec_valor, monto,
              nro_cuenta, cod_moneda, cod_oficina, cod_error,
              cod_retencion, fec_fin_retencion, est_cuenta, estado,
              cod_causa, cod_banco, cod_ofi_origen, concepto,
              cod_tasa, val_tasa, cod_rubro, cod_ref_cambio,
              reversado, cod_usu_reversion, hor_reversion, emi_aviso,
              cod_tra_padre, cod_mod_padre, cod_mad_padre, cod_transaccion,
              cod_modulo, cod_modalidad, mto_equ_local, nro_caja,
              cotizacion, cod_bco_central, nro_documento, nro_documento2,
              nro_documento3, nro_documento4, protegido, cod_autorizacion,
              cod_usu_autorizador, tip_mov_rubro, cod_tip_ope_cambio, referencia,
              cod_persona, cod_sit_contable
      )
      SELECT fecha, hora, cod_usuario, nro_secuencia, fec_valor, monto,
              nro_cuenta, cod_moneda, cod_oficina, cod_error,
              cod_retencion, fec_fin_retencion, est_cuenta, estado,
              cod_causa, cod_banco, cod_ofi_origen, concepto,
              cod_tasa, val_tasa, cod_rubro, cod_ref_cambio,
              reversado, cod_usu_reversion, hor_reversion, emi_aviso,
              cod_tra_padre, cod_mod_padre, cod_mad_padre, cod_transaccion,
              cod_modulo, cod_modalidad, mto_equ_local, nro_caja,
              cotizacion, cod_bco_central, nro_documento, nro_documento2,
              nro_documento3, nro_documento4, protegido, cod_autorizacion,
              cod_usu_autorizador, tip_mov_rubro, cod_tip_ope_cambio, referencia,
              cod_persona, cod_sit_contable
              FROM CC_MOVIMIENTOS_HIS A
              WHERE A.FECHA = v_fecha
                AND EXISTS (SELECT 1
                              FROM LC_OPE_CAM_MIN_BCP_TMP X
                             WHERE X.FECHA = A.FECHA
                               AND X.HORA = A.HORA
                               AND X.COD_USUARIO = A.COD_USUARIO)
                and not exists (select 1
                                  from LC_OPE_CAM_MIN_BCP_TMP z
                                 where z.fecha = a.fecha
                                   and z.hora = a.hora
                                   and z.cod_usuario = a.cod_usuario
                                   and z.nro_secuencia = a.nro_secuencia);

      commit;

      --Insertar en tabla del informe final--
      insert into LC_OPE_CAM_MIN_BCP_DET
      (fec_registro, fecha, tip_documento, nro_documento,
       nom_cliente, fec_ven_forward, mercado, ciudad,
       tip_operacion, tip_canje, com_moneda, com_monto,
       com_precio, com_mto_usd, vta_moneda, vta_monto,
       vta_precio, vta_mto_usd, tip_interno, nro_doc_ope,
       cod_ofi_cambio, tot_equ_compra, tot_equ_venta,
       cod_persona, nro_cuenta, nro_cta_contra,
       hora, cod_usuario, cod_tip_operacion, des_tip_operacion,
       cod_tip_ope_contra, des_tip_ope_contra, afe_posicion,
       seg_operacion, env_bcp, inc_posicion,
       cod_mad_padre, nro_secuencia)
      select nvl(fut.fec_operacion,mo.fecha) fecha_registro, mo.fecha fecha_operacion,

                   --substr(doc.abreviatura,1,3) tipo_documento,
                   decode(fue_obt_tip_doc_abreviatura(doc.cod_tip_documento), 'DNI', 'CRC', 'PAS', 'CRC', 'SW', 'CRC', 'OTR', 'CRC', 'PJ', 'CRC',
                   fue_obt_tip_doc_abreviatura(doc.cod_tip_documento)) tipo_documento,

                   --per.nro_documento,
                   decode(fue_obt_tip_doc_abreviatura(doc.cod_tip_documento), 'CRP',
                    (SELECT TRIM(leading '0' FROM per.nro_documento) FROM dual), per.nro_documento) nro_documento,

                   per.nom_completo nombre_cliente,
                   fut.fec_vencimiento fec_ven_forward,

                   --Mercado--
                   case when ((tca.afe_posicion = 'E') and
                              (tca.cod_modalidad not in (73,74)) and
                              (mo.cod_moneda = 'USD')) then 2 --EFECTIVO'--
                        when nvl(fut.cod_mad_padre,-9) = 76 and nvl(fut.tip_liquidacion,'XXX') <> 'NDF' then 3 --FORWARD'--
                        when tca.cod_modalidad = 74 then 4 --CANJE'--
                        when tca.cod_modalidad = 73 then 5 --ARBITRAJE'--
                        when nvl(fut.cod_mad_padre,-9) = 76 and nvl(fut.tip_liquidacion,'XXX') = 'NDF' then 6 --NDF'--
                        when mo.cod_moneda <> 'USD' then 7 --OP.NO'--
                   else 1 --SPOT'--
                   end mercado,

                   --Ciudad segun resolucion de BCP--
                   fug_obt_pardinamico('COD_CIU_RCF_BCP',
                                        null, null, null,
                                        decode(mo.cod_usuario,'HBANK',cl.cod_oficina,
                                                              'HOMEBANK',cl.cod_oficina,mo.cod_ofi_origen),
                                        null) ciudad,

                   --Tipo Operacion--
                   CASE
                     WHEN tca.cod_modalidad = 71 then 0 --COMPRA'
                     WHEN tca.cod_modalidad = 72 then 1 --VENTA'
                     WHEN tca.cod_modalidad = 74 then 2 --CANJE'
                    ELSE 3 --ARBITRAJE'
                    END TIPO_OPERACION,

                   --Tipo de Canje--
                   case
                     when ((tca.cod_modalidad = 74) and
                           (tca.cod_tip_operacion in (74,743,742,745,744)) and
                           (mo2.cod_tip_ope_cambio = 91)) then 10
                     when ((tca.cod_modalidad = 74) and
                           (tca.cod_tip_operacion = 91) and
                           (mo2.cod_tip_ope_cambio in (74,743,742,745,744))) then 10
                     when ((tca.cod_modalidad = 74) and
                           (tca.cod_tip_operacion = 75) and
                           (mo2.cod_tip_ope_cambio = 89)) then 13
                     when ((tca.cod_modalidad = 74 and tca.cod_tip_operacion = 89) and
                           (tca.cod_modalidad = 74 and mo2.cod_tip_ope_cambio = 75)) then 13
                     else null end TIPO_CANJE,

                   --Campos Compra--
                   decode(o.cod_mad_hijo,71,mo.cod_moneda,null) COMPRA_MONEDA,
                   decode(o.cod_mad_hijo,71,mo.monto,0) COMPRA_MONTO,
                   decode(o.cod_mad_hijo,71,mo.cotizacion,0) COMPRA_PRECIO,
                   decode(o.cod_mad_hijo,71,pal_cam.FU_CON_MON_A_MONEDA(mo.COD_MONEDA, 'USD', mo.monto,mo.cotizacion),0) COMPRA_MONTO_USD,
                   --Campos Venta
                   decode(o.cod_mad_hijo,72,mo.cod_moneda,null) VENTA_MONEDA,
                   decode(o.cod_mad_hijo,72,mo.monto,0) VENTA_MONTO,
                   decode(o.cod_mad_hijo,72,mo.cotizacion,0) VENTA_PRECIO,
                   decode(o.cod_mad_hijo,72,pal_cam.FU_CON_MON_A_MONEDA(mo.COD_MONEDA, 'USD', mo.monto,mo.cotizacion),0) VENTA_MONTO_USD,
                   --Hasta aqui los campos de la Resolucion para BCP--

                   --Inicio de campos para control y seguimiento--
                   'NORMALES' TIPO,
                   MO.NRO_DOCUMENTO nro_doc_ope,
                   decode(mo.cod_usuario,'HBANK',cl.cod_oficina,
                                         'HOMEBANK',cl.cod_oficina,mo.cod_ofi_origen) cod_oficina,
                    nvl( decode(o.cod_mad_hijo,71,mo.monto*mo.cotizacion) ,0 ) tot_equ_compra,
                    nvl( decode(o.cod_mad_hijo,72,mo.monto*mo.cotizacion) ,0 ) tot_equ_venta,
                    decode(cli.cod_mad_padre,76,cli.cod_persona,
                                             nvl(to_char(cli.nro_documento2),cli.cod_persona)) cod_persona,
                    mo.nro_cuenta, mo2.nro_cuenta, mo.hora, mo.cod_usuario,
                    tca.cod_tip_operacion, tca.descripcion,
                    tc2.cod_tip_operacion, tc2.descripcion,
                    tca.afe_posicion,
                    case
                      when pal_cam.FU_CON_MON_A_MONEDA(mo.COD_MONEDA, 'USD', mo.MONTO, mo.cotizacion) < v_bcp_mto_inf_cambios then 'MEN'
                        else 'MAY' end seg_operacion,
                    -------
                    case
                      when (tca.cod_modalidad = 74 and (pal_cam.FU_CON_MON_A_MONEDA(mo.COD_MONEDA, 'USD', mo.MONTO, mo.cotizacion) >= v_bcp_mto_inf_cambios))
                            or
                           (pal_cam.FU_CON_MON_A_MONEDA(mo.COD_MONEDA, 'USD', mo.MONTO, mo.cotizacion) >= v_bcp_mto_inf_cambios)
                            or
                           (decode(cli.cod_mad_padre,76,cli.cod_persona,
                                             nvl(to_char(cli.nro_documento2),cli.cod_persona)) = v_cod_per_entidad) then 'N'
                      else
                        'S'
                      end env_bcp,
                    -------
                    case
                      when tca.cod_modalidad = 74 then 'N' else 'S' end inc_posicion,
                    mo.cod_mad_padre, mo.nro_secuencia
               from LC_OPE_CAM_MIN_BCP_TMP mo, lc_tip_operaciones o, LC_OPE_CAM_MIN_BCP_TMP cli,
                    ba_personas per, ba_tip_documentos doc, LC_OPE_CAM_MIN_BCP_TMP mo2,
                    lc_tip_operaciones tca, lc_ope_futuras fut, lc_tip_operaciones tc2,
                    ge_clientes cl
              where mo.fecha = v_fecha
                and mo.cod_mod_padre = 7
                and mo.cod_mad_padre IN (71,72,73) --Excluido 74-Canje--
                and mo.reversado = 'N'
                and mo.estado = 'N'
                and mo.nro_secuencia in (1,2)
                and mo2.nro_secuencia in (1,2)
                and mo.cod_tip_ope_cambio = o.cod_tip_operacion
                and mo.fecha = cli.fecha
                and mo.hora = cli.hora
                and mo.cod_usuario = cli.cod_usuario
                and mo.nro_secuencia <> cli.nro_secuencia
                and cli.cod_transaccion = 760
                and cli.reversado = 'N'
                and per.cod_persona = decode(cli.cod_mad_padre,76,cli.cod_persona,
                                             nvl(to_char(cli.nro_documento2),nvl(cli.cod_persona,fug_obt_cli_principal(cli.nro_cuenta))))
                and doc.cod_tip_documento = per.cod_tip_documento
                and tca.cod_tip_operacion = mo.cod_tip_ope_cambio
                and fut.nro_referencia(+) = mo.nro_documento2
                and fut.cod_tip_referencia(+) = mo.cod_ref_cambio
                and fut.cod_mad_padre(+) = 76
                and mo.fecha = mo2.fecha
                and mo.hora = mo2.hora
                and mo.cod_usuario = mo2.cod_usuario
                and mo.nro_secuencia <> mo2.nro_secuencia
                and tca.afe_posicion IN ('E', 'O')
                and per.cod_persona = cl.cod_persona
                and tc2.cod_tip_operacion(+) = mo2.cod_tip_ope_cambio;

      --Actualizaciones necesarias para datos de BCP--
      lp_act_dat_inconsistentes;
      lp_act_cod_tip_ope_contra;
      lp_act_tip_can_env_bcp;
      lp_act_uni_ope_arbitraje;
      lp_gen_nro_reg_env_bcp;

       if  v_mensaje_error is  null then
          commit;
       else
          RAISE_APPLICATION_ERROR(-20001,v_mensaje_error);
       end if;
exception
  when others then
           RAISE_APPLICATION_ERROR(-20001,'Error. en prl_gen_dat_ope_cambios: '||v_mensaje_error||' '||sqlerrm);
end;
/

