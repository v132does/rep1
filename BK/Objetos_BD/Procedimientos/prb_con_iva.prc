CREATE OR REPLACE PROCEDURE IT.PRB_CON_IVA (p_fecha in date DEFAULT null) is
--Diario--
cursor cu_con_iva_dia(p_fecha date) is
select c1.orden orden, c1.orden2,
         c1.detalle detalle, sum(nvl(c1.importe,0)) importe,
         c2.detalle detalle2, sum(nvl(c2.importe,0)) importe2
  from
(
    select 1 orden, 1 orden2, '1.1 Credito 10%' detalle,
           sum(a.mto_mon_local) importe
      from cb_asi_automaticos_det a
     where a.fecha = p_fecha
       and a.cod_rubro in ('240102440100199')
       and a.tip_movimiento = 'C'
  union
    select 2 orden, 1 orden2, '2.1 Credito 5%' detalle,
           sum(a.mto_mon_local) importe
      from cb_asi_automaticos_det a
     where a.fecha = p_fecha
       and a.cod_rubro in ('240102440100299')
       and a.tip_movimiento = 'C'
  union
    select 3 orden, 1 orden2, '3.1 Debito 10%' detalle,
           sum(a.mto_mon_local) importe
      from cb_asi_automaticos_det a
     where a.fecha = p_fecha
       and a.cod_rubro in ('240102440100199')
       and a.tip_movimiento = 'D'
  union
    select 4 orden, 1 orden2, '4.1 Debito 5%' detalle,
           sum(a.mto_mon_local) importe
      from cb_asi_automaticos_det a
     where a.fecha = p_fecha
       and a.cod_rubro in ('240102440100299')
       and a.tip_movimiento = 'D'
--
  union
--Reversado del D풹 - Credito* 10%
    select 1 orden, 2 orden2, '1.2 Rev. del D풹 10%' detalle,
           nvl(sum(decode(g.cod_moneda, 'GS', nvl(g.monto, 0),
                                           nvl(g.mto_equ_local, 0))),0) importe
       from gv_movimientos g, cb_asi_automaticos_det a
      where g.nro_documento4 = a.ref_movimiento
        and g.fecha = a.fecha
        and a.cod_rubro in ('240102440100199')
        and g.val_tasa    = 10
        and g.monto       < 0
        and g.tipo        = 'H'
        --and g.reversado = 'S'
        and g.fec_valor   = g.fecha
        and g.fecha       = p_fecha
--
  union
--Reversado del D풹 - Debito * 10%
--Diario
   select 3 orden, 2 orden2, '3.2 Rev. del D풹 10%' detalle,
          nvl(sum(decode(g.cod_moneda, 'GS', nvl(g.monto, 0),
                                           nvl(g.mto_equ_local, 0))),0) importe
     from gv_movimientos g, cb_asi_automaticos_det a
    where g.nro_documento4 = a.ref_movimiento
      and g.fecha = a.fecha
      and a.cod_rubro in ('240102440100199')
      and g.val_tasa    = 10
      and g.monto       < 0
      and g.tipo        = 'H'
      --and g.reversado = 'S'
      and g.fec_valor   = g.fecha
      and g.fecha       = p_fecha

 union
--Reversado del D풹 - Credito* 5%
  --Diario
  --Para mostrar Informe Financiero 5%
    select 2 orden, 2 orden2, ' ' detalle, --'2.2 Rev. del D풹 5%' detalle,
           nvl(sum(decode(g.cod_moneda, 'GS', nvl(g.monto, 0),nvl(g.mto_equ_local, 0))),0)*0 importe
       from gv_movimientos g
      where g.val_tasa       = 5
        and g.monto          < 0
        and g.tipo           = 'H'
        --and g.reversado = 'S'
        and g.fec_valor      = g.fecha
        and g.fecha          = p_fecha

 union
--Reversado del Mes - Debito * 10%
   select 3 orden, 3 orden2, '3.3 Rev. del Mes 10%' detalle,
          nvl(sum(decode(g.cod_moneda, 'GS', nvl(g.monto, 0),
                                         nvl(g.mto_equ_local, 0))),0) importe
     from gv_movimientos g, cb_asi_automaticos_det a
    where g.nro_documento4 = a.ref_movimiento
      and g.fecha = a.fecha
      and a.cod_rubro in ('240102440100199')
      and g.val_tasa  = 10
      and g.monto     < 0
      and g.tipo      = 'H'
      and g.fec_valor <> g.fecha
      and g.fecha     = p_fecha
      and to_char(g.fec_valor,'MM/YYYY') = to_char(p_fecha, 'MM/YYYY')
 union
  --Reversado del Mes - Debito * 5%
   select 4 orden, 3 orden2, '4.3 Rev. del Mes 5%' detalle,
          nvl(sum(decode(g.cod_moneda, 'GS', nvl(g.monto, 0),
                                         nvl(g.mto_equ_local, 0))),0) importe
     from gv_movimientos g, cb_asi_automaticos_det a
    where g.nro_documento4 = a.ref_movimiento
      and g.fecha = a.fecha
      and a.cod_rubro in ('240102440100299')
      and g.val_tasa  = 5
      and g.monto     < 0
      and g.tipo      = 'H'
      and g.fec_valor <> g.fecha
      and g.fecha     = p_fecha
      and to_char(g.fec_valor,'MM/YYYY') = to_char(p_fecha, 'MM/YYYY')
  ) c1,
  (
    select lv.orden, lv.orden2, lv.detalle, sum(nvl(importe,0)) importe
    from
    (
      select 1 orden, 1 orden2, '1.1 Facturas 10%' detalle,
             sum(l.impuesto_10_gs) importe
        from cb_lib_ventas_det_tmp l
       where l.fecha = p_fecha
         and l.reversado = 'N'
    union
      select 1 orden, 1 orden2, '1.1 Facturas 10%' detalle,
             sum(d.impuesto_10_gs) importe
        from cb_lib_ventas c, cb_lib_ventas_det d
       where c.nro_factura = d.nro_factura
         and c.nro_timbrado = d.nro_timbrado
         and c.tip_comprobante = 'F'
         and d.fecha = p_fecha
         and d.impuesto_10_gs <> 0
     ) lv
  group by lv.orden, lv.orden2, lv.detalle
 union
  select lv.orden, lv.orden2, lv.detalle, sum(nvl(importe,0)) importe
  from
  (
    select 2 orden, 1 orden2, '2.1 Facturas 5%' detalle,
           sum(l.impuesto_5_gs) importe
      from cb_lib_ventas_det_tmp l
     where l.fecha = p_fecha
       and l.reversado = 'N'
   union
    select 2 orden, 1 orden2, '2.1 Facturas 5%' detalle,
           sum(d.impuesto_5_gs) Importe
      from cb_lib_ventas c, cb_lib_ventas_det d
     where c.nro_factura = d.nro_factura
       and c.nro_timbrado = d.nro_timbrado
       and c.tip_comprobante = 'F'
       and d.fecha = p_fecha
       and d.impuesto_5_gs <> 0
   ) lv
   group by lv.orden, lv.orden2, lv.detalle

 union

 select lv.orden, lv.orden2, lv.detalle, sum(nvl(importe,0)) importe
   from
 (
    select 3 orden, 1 orden2, '3.1 Notas CR 10%' detalle,
           sum(l.impuesto_10_gs) importe
      from cb_lib_ventas_det_tmp l
     where l.fecha = p_fecha
       and l.reversado = 'S'
  union
    select 3 orden, 1 orden2, '3.1 Notas CR 10%' detalle,
           sum(d.impuesto_10_gs) importe
      from cb_lib_ventas c, cb_lib_ventas_det d
     where c.nro_factura = d.nro_factura
       and c.nro_timbrado = d.nro_timbrado
       and c.tip_comprobante = 'N'
       and d.fecha = p_fecha
       and d.impuesto_10_gs <> 0
  ) lv
  group by lv.orden, lv.orden2, lv.detalle

 union

 select lv.orden, lv.orden2, lv.detalle, sum(nvl(importe,0)) importe
   from
 (
    select 4 orden, 1 orden2, '4.1 Notas CR 5%' detalle,
           sum(l.impuesto_5_gs) importe
      from cb_lib_ventas_det_tmp l
     where l.fecha = p_fecha
       and l.reversado = 'S'
  union
    select 4 orden, 1 orden2, '4.1 Notas CR 5%' detalle,
           sum(d.impuesto_5_gs) Importe
      from cb_lib_ventas c, cb_lib_ventas_det d
     where c.nro_factura = d.nro_factura
       and c.nro_timbrado = d.nro_timbrado
       and c.tip_comprobante = 'N'
       and d.fecha = p_fecha
       and d.impuesto_5_gs <> 0
 ) lv
  group by lv.orden, lv.orden2, lv.detalle

 union
   select 1 orden, 2 orden2, '1.2 Informe Financiero 10%' detalle,
          sum(d.mto_mon_local) importe
     from cb_asi_automaticos_det d
    where d.cod_rubro in ('240102440100199')
      and d.referencia     is not null
      and d.mto_mon_local <> 0
      and d.fecha          = p_fecha
 union
   select 2 orden, 2 orden2, '2.2 Informe Financiero 5%' detalle,
          sum(d.mto_mon_local) importe
     from cb_asi_automaticos_det d
    where d.cod_rubro  in ('240102440100299')
      and d.referencia     is not null
      and d.mto_mon_local <> 0
      and d.fecha          = p_fecha
  ) c2
  where c1.orden = c2.orden(+)
    and c1.orden2 = c2.orden2(+)
  group by c1.orden, c1.orden2, c1.detalle, c2.detalle

union all

  select c3.orden orden, c3.orden2 orden2,
         c3.detalle detalle, sum(nvl(c3.importe,0)) importe,
         null detalle2, null importe2
  from
 (
    select 8 orden, 1 orden2, '8.1 Credito 10% Manual' detalle,
          sum(d.mto_mon_local) importe
     from cb_asientos_det_his d
    where d.cod_rubro in ('240102440100199')
      and d.tip_movimiento = 'C'
      and d.fecha          = p_fecha
  union
    select 8 orden, 2 orden2, '8.2 Credito 5% Manual' detalle,
          sum(d.mto_mon_local) importe
     from cb_asientos_det_his d
    where d.cod_rubro in ('240102440100299')
      and d.tip_movimiento = 'C'
      and d.fecha          = p_fecha
  union
    select 8 orden, 3 orden2, '8.3 Debito 10% Manual' detalle,
          sum(d.mto_mon_local) importe
     from cb_asientos_det_his d
    where d.cod_rubro in ('240102440100199')
      and d.tip_movimiento = 'D'
      and d.fecha          = p_fecha
  union
    select 8 orden, 4 orden4, '8.4 Debito 5% Manual' detalle,
          sum(d.mto_mon_local) importe
     from cb_asientos_det_his d
    where d.cod_rubro in ('240102440100299')
      and d.tip_movimiento = 'D'
      and d.fecha          = p_fecha
 ) c3
 group by c3.orden, c3.orden2, c3.detalle

order by 1, 2, 3;

--Mensual--
cursor cu_con_iva_mes(p_fec_ini date, p_fec_fin date, p_cod_oficina ba_oficinas.cod_oficina%type) is
  select c1.orden orden, c1.detalle detalle, sum(nvl(c1.importe,0)) importe,
         c2.detalle detalle2, sum(nvl(c2.importe,0)) importe2
  from(
     select 1 orden, '1.1 Credito 10%' detalle,
            sum(a.mto_mon_local) importe
      from cb_asientos_det_his a
     where a.fecha >= p_fec_ini
       and a.fecha <= p_fec_fin
       and a.cod_rubro in ('240102440100199')
       and a.tip_movimiento = 'C'
   union
     select 2 orden, '2.1 Credito 5%' detalle,
            sum(a.mto_mon_local) importe
       from cb_asientos_det_his a
      where a.fecha >= p_fec_ini
        and a.fecha <= p_fec_fin
        and a.cod_rubro in ('240102440100299')
        and a.tip_movimiento = 'C'
   union
     select 3 orden, '3.1 Debito 10%' detalle,
            sum(a.mto_mon_local) importe
       from cb_asientos_det_his a
      where a.fecha >= p_fec_ini
        and a.fecha <= p_fec_fin
        and a.cod_rubro in ('240102440100199')
        and a.tip_movimiento = 'D'
   union
     select 4 orden, '4.1 Debito 5%' detalle,
            sum(a.mto_mon_local) importe
       from cb_asientos_det_his a
      where a.fecha >= p_fec_ini
        and a.fecha <= p_fec_fin
        and a.cod_rubro in ('240102440100299')
        and a.tip_movimiento = 'D'
   ) c1,
(
    select 1 orden, '1.1 Facturas 10%' detalle,
           sum(l.impuesto_10_gs) importe
     from cb_lib_ventas_det l,
          cb_lib_ventas c
     where l.fecha >= p_fec_ini
       and l.fecha <= p_fec_fin
     and l.nro_factura = c.nro_factura
     and l.nro_timbrado = c.nro_timbrado
     and c.tip_comprobante = 'F'
  union
    select 2 orden, '2.1 Facturas 5%',
           sum(l.impuesto_5_gs) importe
     from cb_lib_ventas_det l,
          cb_lib_ventas c
     where l.fecha >= p_fec_ini
       and l.fecha <= p_fec_fin
       and l.nro_factura = c.nro_factura
       and l.nro_timbrado = c.nro_timbrado
       and c.tip_comprobante = 'F'
  union
    select 3 orden, '3.1 Notas CR 10%' detalle,
           sum(l.impuesto_10_gs) importe
     from cb_lib_ventas_det l,
          cb_lib_ventas c
     where l.fecha >= p_fec_ini
       and l.fecha <= p_fec_fin
       and l.nro_factura = c.nro_factura
       and l.nro_timbrado = c.nro_timbrado
       and c.tip_comprobante = 'N'
  union
    select 4 orden, '4.1 Notas CR 5%' detalle,
           sum(l.impuesto_5_gs) importe
     from cb_lib_ventas_det l,
          cb_lib_ventas c
     where l.fecha >= p_fec_ini
       and l.fecha <= p_fec_fin
       and l.nro_factura = c.nro_factura
       and l.nro_timbrado = c.nro_timbrado
       and c.tip_comprobante = 'N'
 ) c2
  where c1.orden = c2.orden(+)
  group by c1.orden, c1.detalle, c2.detalle

union all

  select c3.orden orden1, c3.detalle detalle1, sum(nvl(c3.importe,0)) importe1,
         null detalle2, null importe2
  from
(
  --Transacciones Manuales
     select 7 orden, ('7.1 Debito 10% '||d.descripcion ||' '|| d.fecha) detalle,
            d.mto_mon_local importe --,
            --'D' tipo
       from cb_asientos_det_his d
      where nvl(d.ref_movimiento,0) = 0
        --and d.cod_oficina           = to_number(fug_obt_pardinamico('PRV_COD_OFI_PAG_PROVEEDORES')) --31
        and d.cod_oficina           = p_cod_oficina -- CN 05/08/2014 --SC4896--
        and d.tip_movimiento        = 'D'
        and d.cod_rubro in ('240102440100199')
        and d.fecha >= p_fec_ini
        and d.fecha <= p_fec_fin
  union
  --Transacciones Manuales
     select 7 orden, ('7.2 Debito 5% '||d.descripcion ||' '|| d.fecha) detalle,
            d.mto_mon_local importe --,
            --'D' tipo
       from cb_asientos_det_his d
      where nvl  (d.ref_movimiento,0) = 0
        --and d.cod_oficina           = to_number(fug_obt_pardinamico('PRV_COD_OFI_PAG_PROVEEDORES')) --31
        and d.cod_oficina           = p_cod_oficina -- CN 05/08/2014 --SC4896--
        and d.tip_movimiento        = 'D'
        and d.cod_rubro in ('240102440100299')
        and d.fecha >= p_fec_ini
        and d.fecha <= p_fec_fin
 ) c3
  group by c3.orden, c3.detalle

  order by 1,2;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_name             VARCHAR2(128) := 'control_iva';
  v_separador        VARCHAR2(10)  := chr(59);
  v_linea            VARCHAR2(4000);
  v_file             VARCHAR2(4000);
  v_detalle          CLOB;--VARCHAR2(4000);
  v_detalles         VARCHAR2(4000);
  v_nombre           varchar2(100);
  v_asunto           varchar2(100);
  v_contenido        varchar2(400);
  v_dir_correo_de    varchar2(100) := fug_obt_pardinamico('CAM_MAR_DIR_MAI_NET');--'bbvanet@bbva.com.py';
  v_dir_correo_para  varchar2(4000);
  conn               utl_smtp.connection;
--
  v_ult_dia_mes_habil DATE;
  v_fec_ini DATE;
  v_fec_fin DATE;

  -- CN 05/08/2014 --SC4896--
  v_cod_oficina number;
  -- Variables para mail 
  v_hini_mail        ge_ra_log_mail.hor_inicio%type;
  v_hfin_mail        ge_ra_log_mail.hor_fin%type;
  v_det_error        ge_ra_log_mail.det_error%type;
   --Acceso FTP
  v_archivo          utl_file.file_type;
  v_directorio       varchar2(20) := pag_evo.g_repository;
  g_ip               varchar2(100) := pag_evo.g_ip;
  g_port             varchar2(100) := pag_evo.g_port;
  g_user             varchar2(100) := pag_evo.g_user;
  g_pass             varchar2(100) := pag_evo.g_pass;
  v_dir_ramail       varchar2(100) := pag_evo.g_contabilidad;
  
begin

  --CN--09/04/2014--
  if p_fecha is null then
    --Obtenemos la fecha anterior del sistema
    v_fec_sist := pag_cal.FU_OBT_FEC_ANTERIOR(2);
  else
    v_fec_sist := p_fecha;
  end if;

  --Buscar el ultimo dia habil del mes
  v_ult_dia_mes_habil := pag_cal.fu_obt_fec_habil(last_day(v_fec_sist),-1,2);
  v_dir_correo_para   := pa_rep_aut.FU_OBT_VALOR_PAR('RA','REPORTES','IVA'); /* Agregado por MS en fecha 28/03/2014 */
  v_asunto            := 'Informe seguimiento del IVA '||to_char(v_fec_sist,'dd/mm/yyyy')||'.';
  v_contenido         := 'Adjunto archivo conteniendo los datos del Informe seguimiento del iva';
  v_nombre            := v_name||'_'||to_char(v_fec_sist,'ddmmyyyy')||'.csv';
  
begin
   -- ramail --
    v_archivo   := utl_file.fopen(v_directorio, v_nombre, 'W', 32767);
    v_hini_mail := to_char(sysdate,'hh24:mi:ss');

    v_linea := 'MOVIMIENTOS CONTABLES' || v_separador || 'IMPORTE' || v_separador || v_separador ||
               'MOVIMIENTOS LIBRO' || v_separador || 'IMPORTE' || v_separador || 'DIFERENCIAS' || chr(10);
    v_file  := v_file || v_linea;
    
    v_detalle := v_file||chr(10);

    -- ramail --
    utl_file.put_line(v_archivo, v_linea);
    --CN--09/04/2014--
    if v_fec_sist <> v_ult_dia_mes_habil then --Diario
      FOR c IN cu_con_iva_dia(v_fec_sist) LOOP
          v_detalle := v_detalle || to_char(c.detalle) || v_separador || to_char(c.importe) || v_separador ||v_separador ||
          to_char(c.detalle2)|| v_separador || to_char(c.importe2)|| chr(10);
          -- ramail --
          v_detalles :=  v_detalles || to_char(c.detalle) || v_separador || to_char(c.importe) || v_separador ||v_separador ||
          to_char(c.detalle2)|| v_separador || to_char(c.importe2) ;
           -- ramail --
          utl_file.put_line(v_archivo, v_detalles);
          v_detalles := '';
          if c.orden = 1 and c.orden2 = 2 then
            v_detalle := v_detalle||chr(10)||chr(10);
           -- ramail --
           utl_file.put_line(v_archivo, v_detalles);
           v_detalles := '';
          end if;
          if c.orden = 2 and c.orden2 = 2 then
            v_detalle := v_detalle||chr(10)||chr(10);
            -- ramail --
            utl_file.put_line(v_archivo, v_detalles);
            v_detalles := '';
          end if;
          if c.orden = 3 and c.orden2 = 3 then
            v_detalle := v_detalle||chr(10)||chr(10);
            -- ramail --
            utl_file.put_line(v_archivo, v_detalles);
            v_detalles := '';
          end if;
          if c.orden = 4 and c.orden2 = 3 then
            v_detalle := v_detalle||chr(10)||chr(10);
            -- ramail --
            utl_file.put_line(v_archivo, v_detalles);
            v_detalles := '';
          end if;
       END LOOP;
       utl_file.fclose(v_archivo);       
    else --Mensual
       v_fec_ini := trunc(v_fec_sist,'MM');
       v_fec_fin := v_fec_sist;
        
       -- CN 05/08/2014 --SC4896--
       -- Se obtiene previamente el valor de cod_oficina y se le env풹 como par퓅etro al cursor --
       v_cod_oficina := to_number(fug_obt_pardinamico('PRV_COD_OFI_PAG_PROVEEDORES'));        
       FOR c IN cu_con_iva_mes(v_fec_ini,v_fec_fin,v_cod_oficina) LOOP
          v_detalle := v_detalle || to_char(c.detalle) || v_separador || to_char(c.importe) || v_separador ||v_separador ||
          to_char(c.detalle2)|| v_separador || to_char(c.importe2)|| chr(10);
          -- ramail --
          v_detalles := v_detalles || to_char(c.detalle) || v_separador || to_char(c.importe) || v_separador ||v_separador ||
          to_char(c.detalle2)|| v_separador || to_char(c.importe2);
            -- ramail --
          utl_file.put_line(v_archivo, v_detalles);
          v_detalles := '';
          if c.orden = 2 then
            v_detalle := v_detalle||chr(10)||chr(10);
              -- ramail --
            utl_file.put_line(v_archivo, v_detalles);
            v_detalles := '';
          end if;  
          if c.orden = 4 then
            v_detalle := v_detalle||chr(10)||chr(10);
            -- ramail --
            utl_file.put_line(v_archivo, v_detalles);
            v_detalles := '';
          end if;        
       END LOOP;
       utl_file.fclose(v_archivo);
    end if;
    
    it_mail.mail_attach(sender     => v_dir_correo_de,
                        recipients => v_dir_correo_para,
                        subject    => v_asunto,
                        message    => v_contenido,
                        data       => v_detalle,
                        filename   => v_nombre);
                                                     

  exception
    when utl_smtp.transient_error or utl_smtp.permanent_error then
      begin
        utl_smtp.quit(conn);
      exception
        when utl_smtp.transient_error or utl_smtp.permanent_error then
          dbms_output.put_line ('Error1: '||sqlerrm);
      end;
      v_det_error := substr(sqlerrm,1,4000);
    when others then
      begin
        utl_smtp.quit(conn);
      exception
        when utl_smtp.transient_error or utl_smtp.permanent_error then
          dbms_output.put_line ('Error2: '||sqlerrm);
      end;
      v_det_error := substr(sqlerrm,1,4000);
  end;  
  -- CN 05/08/2014 --SC4896--
  -- Se agrega para que en caso de error registre el log --
  v_hfin_mail := to_char(sysdate,'hh24:mi:ss');
  -- Insertamos en la tabla de log si ocurrio algun error al enviar el mail
  if v_det_error is not null then
       begin
         begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
         insert into ge_ra_log_mail(fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
         values(sysdate, v_nombre, v_dir_correo_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
         commit;
       end;
  end if;
  -- Envio del archivo al directorio FTP --
  begin
    declare
      v_conn UTL_TCP.connection;
    begin
      v_conn := utl_ftp.login(g_ip, g_port, g_user, g_pass);
      utl_ftp.ascii(p_conn => v_conn);
      utl_ftp.put(p_conn      => v_conn,
                  p_from_dir  => v_directorio,
                  p_from_file => v_nombre,
                  p_to_file   => v_dir_ramail || v_nombre);
      utl_ftp.logout(v_conn);
      UTL_TCP.close_all_connections;
    exception
      when others then
        UTL_TCP.close_connection(v_conn);
        raise;
    end;
end;
exception
  when others then
    raise_application_error(-20000,'Error al Generar Informe seguimiento del IVA. '||sqlerrm);
end;
/

