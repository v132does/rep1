create or replace function it.FUJ_IMP_COMPROBANTE_250
  (p_nro_operacion in number,
   p_cod_oficina   in number,
   p_nro_caja      in number)
 return varchar2 is
  --comprimido 40 de ancho
  v_ancho     	 	 number(3) := 40; -- ancho del reporte
  v_resultado 		 varchar2(4000) := null;
  v_linea     		 varchar2(200);
  v_fecha          date := SYSDATE;
  v_hora           varchar2(8) := to_char(sysdate,'hh24:mi:ss');
  v_col_antes      number;
  --
  v_nro_cuenta      varchar2(15);
  v_nro_tarjeta     ta_tarjetas.nro_tarjeta%type;
  v_denominacion    varchar2(100);
  v_des_modalidad   varchar2(100);
  v_cod_moneda      varchar2(4);
  v_des_moneda      varchar2(100);
  v_monto           number(18,2);
  v_des_monto       varchar2(300);
  v_des_transaccion varchar2(200);
  --
  v_nro_impresion       number(10);
  v_cod_tip_ope_cambio  varchar2(6);
  v_des_tip_operacion   varchar2(100);
  v_nom_usuario         varchar2(100);
  v_cod_ope_bcp         varchar2(6);
  v_des_ope_bcp         varchar2(100);
  v_referencia          varchar2(20);
  v_cotizacion          ge_cotizaciones.val_conversion%type;
  v_mto_equ_local       number(18);
  v_cta_cambios         varchar2(20);
  v_nro_documento       varchar2(20);
  v_nom_persona         varchar2(200);
  v_importe             number;
  v_una_vez             varchar2(1) :='S';
  v_cod_usuario         varchar2(10);
  v_sigla               ge_bancos.sigla%type;
  v_nro_documento3      ge_movimientos.nro_documento3%type;
  v_det_pago            number(18,2);


  cursor det is
   select cod_transaccion,monto
    from ge_movimientos mov
   where mov.estado = 'N'
     and mov.cod_tra_padre = 250
     and mov.cod_transaccion in (690,606,607,610,632)
     and mov.reversado = 'N'
     and mov.nro_documento = p_nro_operacion
     and mov.nro_caja = p_nro_caja;

begin
  -- seteo la oficina
  pag_imp.pr_set_oficina(p_cod_oficina);
  -- seteo el ancho del reporte
  pag_imp.pr_set_ancho(v_ancho); -- ancho del comprobante
  --imprimir nro de impresion, x ahora no se enumeran
  v_nro_impresion := 0;
  Begin
    Select nvl(count(*),0)
      into v_nro_impresion
      from cj_movimientos
     where cod_tra_padre = 110
       and cod_mod_padre = 9
       and cod_mad_padre = 91
       and nro_documento = p_nro_operacion;
  End;   
  begin
  select distinct substr(a.concepto,-16) nro_tarjeta,
         c.denominacion,
         a.cod_moneda moneda,
         e.descripcion des_moneda,
         mon.monto monto,
         f.descripcion,
         d.descripcion
     into v_nro_tarjeta, v_denominacion,
         v_cod_moneda, v_des_moneda, v_monto, 
         v_des_transaccion, v_des_modalidad      
    from ge_transacciones f, ba_monedas e, ge_modalidades d, ta_cta_tarjetas c, ge_cta_clientes r, ge_movimientos a,
         (select nro_documento,nro_caja, sum(monto) monto from ge_movimientos mov
           where mov.estado = 'N'
             and mov.cod_tra_padre = 250
             and mov.cod_transaccion in (690,606,607,610,632)
             and mov.reversado = 'N'
          group by mov.nro_documento, nro_caja) mon
   where a.nro_cuenta = c.nro_cuenta
     and d.cod_modulo = c.cod_modulo
     and d.cod_modalidad = c.cod_modalidad
     and e.cod_moneda = a.cod_moneda
     and a.estado = 'N'
     and r.nro_cuenta = c.nro_cuenta
     and r.relacion = 'P'
     and a.nro_documento = p_nro_operacion
     and a.cod_tra_padre = 250
     and a.cod_transaccion in (690,606,607,610,632)
     and a.reversado = 'N'
     and f.cod_modulo = a.cod_mod_padre
     and f.cod_modalidad = a.cod_mad_padre
     and f.cod_transaccion = a.cod_tra_padre
     and mon.nro_documento = a.nro_documento
     and mon.nro_caja = a.nro_caja
     and a.nro_caja = p_nro_caja;
  exception
    when no_data_found then
       raise_application_error(-20000,'Operacion inexistente');
  end;

  pag_imp.pr_imp_cab_centrada(v_resultado,'*** '||'PAGO DE TARJETAS'||' ***',null,1);
    -- imprimo la fecha y hora
  v_linea := 'Fecha: '||to_char(v_fecha,'dd/mm/yyyy')||'               '||v_hora;
  pag_imp.pr_imp_linea(v_resultado, v_linea, 1);
  -- Imprimo datos del cajero --ver si el usuario del movimiento = al del mov. de caja
  v_nom_usuario :=fue_obt_nom_usuario(user);
  if fug_obt_tip_implementacion = 1 then
     v_linea := 'Caja: '||rpad(p_nro_caja,4,' ');--||lpad(v_nom_usuario,30,' ');
  else
    v_linea := 'Caja: '||rpad(p_nro_caja,4,' ')||lpad(v_nom_usuario,30,' ');
  end if;
  pag_imp.pr_imp_linea(v_resultado, v_linea, 1);


  --imprimo nro operacion
  if v_nro_impresion = 0 then
    v_linea := 'Numero: '||rpad(p_nro_operacion,8,' ')||'                '||'Original';
    pag_imp.pr_imp_linea(v_resultado,v_linea,1);
  else
    v_linea := 'Numero: '||rpad(p_nro_operacion,8,' ')||'       '||'Copia Nro.: '||lpad(v_nro_impresion,5,' ');
    pag_imp.pr_imp_linea(v_resultado,v_linea,1);
  end if;

  -- detalle de la operacion
  pag_imp.PR_IMP_LINEA(v_resultado,lpad('-',40,'-'),1);
  -- Datos de la Cuenta
  pag_imp.pr_imp_linea(v_resultado,'Tarjeta Nro: '||v_nro_tarjeta,1);
  pag_imp.pr_imp_linea(v_resultado,'Nombre     : '||v_denominacion,1);
  pag_imp.pr_imp_linea(v_resultado,'Tipo       : '||v_des_modalidad,1);
  pag_imp.pr_imp_linea(v_resultado,'Moneda     : '||v_des_moneda,1);

  for i in det loop
    If i.cod_transaccion = 690 then
      pag_imp.pr_imp_linea(v_resultado,'Efectivo       : '|| lpad(to_char(i.monto,'999,999,999,999.99'),22,' '),2);
    elsif i.cod_transaccion = 606 then
      pag_imp.pr_imp_linea(v_resultado,'Cheq.Ntro.Bco  : '|| lpad(to_char(i.monto,'999,999,999,999.99'),22,' '),1);
    elsif i.cod_transaccion in (610,607,632) then
      pag_imp.pr_imp_linea(v_resultado,'Cheq.O/Bancos  : '|| lpad(to_char(i.monto,'999,999,999,999.99'),22,' '),1);
    End if;
  end loop;
  pag_imp.pr_imp_linea(v_resultado,'Total Pagado   :'||v_cod_moneda||' '||lpad(to_char(v_monto,'999,999,999,999.99'),20,' '),2);

  -- imprimo el pie
  pag_imp.pr_imp_pie(v_resultado, 2);   -- linea antes

  v_linea := null;
  pag_imp.pr_imp_linea(v_resultado, v_linea, 8);

  return(v_resultado);

end FUJ_IMP_COMPROBANTE_250;
/

