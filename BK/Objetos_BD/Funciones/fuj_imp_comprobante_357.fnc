CREATE OR REPLACE FUNCTION IT.FUJ_IMP_COMPROBANTE_357
  (
   p_nro_cuenta        in  ah_cta_certificados.nro_cuenta%type,
   p_fecha             in  ge_movimientos.fecha%type,
   p_hora              in  ge_movimientos.hora%type,
   p_cod_usuario       in  ge_movimientos.cod_usuario%type)
 return varchar2 is
   --comprimido 40 de ancho
  v_ancho           number(3) := 40; -- ancho del reporte
  v_resultado      varchar2(4000) := null;
  v_linea          varchar2(200);
  v_fecha          date := SYSDATE;
  v_hora           varchar2(8) := to_char(sysdate,'hh24:mi:ss');
  v_col_antes      number;
  --
  v_nro_cuenta      varchar2(15);
  v_cta_formateada  varchar2(20);
  v_denominacion    varchar2(100);
  v_des_modalidad   varchar2(100);
  v_cod_moneda      varchar2(4);
  v_des_moneda      varchar2(100);
  v_monto           varchar2(100);--number(18,2);
  v_des_monto       varchar2(300);
  v_des_transaccion varchar2(200);
  --
  v_nro_impresion      number(10);
  v_cod_tip_ope_cambio varchar2(6);
  v_des_tip_operacion  varchar2(100);
  v_nom_usuario        varchar2(100);
  v_cod_ope_bcp        varchar2(6);
  v_des_ope_bcp        varchar2(100);
  v_referencia         varchar2(20);
  v_cotizacion         ge_cotizaciones.val_conversion%type;
  v_mto_equ_local      number(18);
  v_cta_cambios        varchar2(20);
  v_nro_documento      ba_personas.nro_documento%type;
  v_tip_persona        ba_personas.tipo%type;
  v_nacionalidad       ba_paises.nacionalidad%type;
  v_nom_persona        varchar2(200);
  v_importe            number;
  v_una_vez            varchar2(1) :='S';
  v_cod_usuario        varchar2(10);
  v_sigla              ge_bancos.sigla%type;
  v_nro_documento3     ge_movimientos.nro_documento3%type;
  v_nombre             ah_cta_certificados.denominacion%type;
  v_efectivo           ge_movimientos.monto%type;
  v_des_efectivo       varchar2(1000);
  v_nstro_bco          ge_movimientos.monto%type;
  v_des_nstro_bco      varchar2(1000);
  v_cod_oficina        ba_oficinas.cod_oficina%type;
  v_nom_oficina        ba_oficinas.descripcion%type;
  v_direccion          ba_direcciones.direccion%type; 
  v_cod_tra_padre      ge_movimientos.cod_tra_padre%type; 
  v_fec_movimiento     varchar2(120);
  v_cod_modulo         ge_movimientos.cod_modulo%type;        
  v_cod_modalidad      ge_movimientos.cod_modalidad%type; 
  v_cod_persona        ba_personas.cod_persona%type; 
  v_det_retencion      varchar2(400);
  
begin
  
  -- seteo el ancho del reporte
  pag_imp.pr_set_ancho(v_ancho); -- ancho del comprobante

  -- leo los datos del movimiento
  begin
      select '***' || trim(to_char(a.monto, '999,999,999,999,999.99')),
             a.nro_cuenta,
             a.cod_moneda,
             b.descripcion,
             d.nro_documento,
             d.tipo,
             e.nacionalidad,
             nvl(f.direccion || decode(numero, null, '', ' ' || numero),
                 ' '),
             cer.denominacion,
             a.cod_tra_padre,
             fug_des_fecha(a.fecha),
             a.cod_modulo,
             a.cod_modalidad,
             d.cod_persona,
             c.cod_oficina,
             m.descripcion ,
             fue_obt_denominacion(a.monto) des_monto
        into v_monto,
             v_nro_cuenta,
             v_cod_moneda,
             v_nom_oficina,
             v_nro_documento,
             v_tip_persona,
             v_nacionalidad,
             v_direccion,
             v_nombre,
             v_cod_tra_padre,
             v_fec_movimiento,
             v_cod_modulo,
             v_cod_modalidad,
             v_cod_persona,
             v_cod_oficina,
             v_des_moneda, 
             v_des_monto
        from ge_movimientos  a,
             ba_oficinas     b,
             ge_cta_clientes c,
             ba_personas     d,
             ba_paises       e,
             ba_direcciones  f,
             ba_monedas      m,
             ah_cta_certificados cer
       where a.fecha = p_fecha
         and a.hora = p_hora
         and a.cod_usuario = p_cod_usuario
         and a.nro_cuenta = p_nro_cuenta
         and a.cod_transaccion = 9603
         and a.cod_ofi_origen = b.cod_oficina
         and a.nro_cuenta = c.nro_cuenta
         and c.relacion = 'P'
         and a.cod_moneda = m.cod_moneda
         and c.cod_persona = d.cod_persona
         and d.cod_pais = e.cod_pais
         and d.cod_persona = f.cod_persona(+)
         and 'S' = f.principal(+)
         and a.nro_cuenta = cer.nro_cuenta
         and a.cod_modulo = cer.cod_modulo
         and a.cod_modalidad = cer.cod_modalidad;

  exception
     when others then
           raise_application_error(-20000,'Error al leer datos del movimiento'||sqlerrm);
  end;

 
  begin
   select 'Ley 6380/2019-retención '||g.VAL_TASA||'% - Cuenta : '||r.nro_cuenta 
        ||' interes '||r.cod_moneda||' '||r.mto_renta
        ||' de fecha '||to_date(r.fec_retencion,'dd/mm/yyyy')
   into v_det_retencion
   from ge_inr_retenciones r, ge_movimientos g 
  where r.nro_cta_credito = g.nro_cuenta
    and r.nro_cuenta = g.nro_cuenta
    and r.fec_retencion = g.fecha
    and g.COD_TRANSACCION = 9603
    and g.NRO_CUENTA = p_nro_cuenta
    and g.FECHA = p_fecha;
  exception
  	when no_data_found then
  		v_det_retencion := 'Ley 6380/2019-retención 15% - Cuenta : '||p_nro_cuenta;
  end;
  
  -- seteo la oficina
  pag_imp.pr_set_oficina(v_cod_oficina);
  -- seteo el ancho del reporte
  pag_imp.pr_set_ancho(v_ancho); -- ancho del comprobante
  --imprimir nro de impresion, x ahora no se enumeran

  pag_imp.pr_imp_cab_centrada(v_resultado,'*** '||'LEY 6380/2019 - Impuesto a la renta No Residentes(INR)'||' ***',null,1);
 
  -- imprimo la fecha y hora
  v_linea := 'Fecha: '||to_char(v_fecha,'dd/mm/yyyy')||'               '||v_hora;
  pag_imp.pr_imp_linea(v_resultado, v_linea, 2);
  -- Imprimo datos del cajero --ver si el usuario del movimiento = al del mov. de caja
  v_nom_usuario :=fue_obt_nom_usuario(user);
 
  -- detalle de la operacion
  pag_imp.PR_IMP_LINEA(v_resultado,lpad('-',40,'-'),1);
  
  v_linea := v_det_retencion;
  pag_imp.pr_imp_linea(v_resultado, v_linea, 0);

  pag_imp.pr_imp_linea(v_resultado,'Total Retenido  : '||v_cod_moneda||' '||v_monto,2);

  pag_imp.pr_imp_linea(v_resultado,initcap(v_des_moneda)||' '||v_des_monto||'.-',2);


  pag_imp.PR_IMP_LINEA(v_resultado,lpad('-',25,'-'),4,0,'S');

  -- imprimo el pie
  pag_imp.pr_imp_pie(v_resultado, 2);   -- linea antes

  v_linea := null;
  pag_imp.pr_imp_linea(v_resultado, v_linea, 8);

  return(v_resultado);
exception
   when others then
      return null;

end FUJ_IMP_COMPROBANTE_357;
/

