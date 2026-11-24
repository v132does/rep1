create or replace function it.FUJ_IMP_COMPROBANTE_204
  (p_nro_operacion in number,
   p_cod_oficina   in number,
   p_nro_caja      in number)
 return varchar2 is
  --comprimido 40 de ancho
  v_ancho           number(3) := 40; -- ancho del reporte
  v_resultado      varchar2(4000) := null;
  v_linea          varchar2(200);
  v_fecha          date := pag_cal.FU_OBT_FEC_ACTUAL(9);
  v_hora           varchar2(8) := to_char(sysdate,'hh24:mi:ss');
  v_cod_moneda      varchar2(4);
  v_des_moneda      varchar2(100);
  v_monto           number(18,2);
  v_des_monto       varchar2(300);
  v_nro_impresion       number(10);
  v_cod_usuario     ba_usuarios.cod_usuario%type;
  v_nro_caj_destino     cj_cajas.nro_caja%type;
  v_cod_usu_destino     ba_usuarios.cod_usuario%type;
begin
  -- seteo la oficina
  pag_imp.pr_set_oficina(p_cod_oficina);
  -- seteo el ancho del reporte
  pag_imp.pr_set_ancho(v_ancho); -- ancho del comprobante
  --imprimir nro de impresión, x ahora no se enumeran
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
  select a.cod_moneda moneda, b.descripcion des_moneda, a.monto, a.cod_usuario,
         a.nro_documento2, a.referencia
    into v_cod_moneda, v_des_moneda, v_monto, v_cod_usuario,
         v_nro_caj_destino, v_cod_usu_destino
    FROM ge_movimientos a, ba_monedas b
   where a.fecha = v_fecha
     and a.nro_documento = p_nro_operacion
     and a.nro_caja = p_nro_caja
     and b.cod_moneda = a.cod_moneda
     and a.cod_tra_padre = 204;
  exception
    when no_data_found then
       raise_application_error(-20000,'Operación inexistente');
  end;

  v_des_monto := fue_obt_denominacion(v_monto);
  pag_imp.pr_imp_cab_centrada(v_resultado,'*** '||'TRANSFERENCIA ENTRE CAJAS'||' ***',null,1);
    -- imprimo la fecha y hora
  v_linea := 'Fecha: '||to_char(v_fecha,'dd/mm/yyyy')||'               '||v_hora;
  pag_imp.pr_imp_linea(v_resultado, v_linea, 1);
  -- Imprimo datos del cajero --ver si el usuario del movimiento = al del mov. de caja
  v_linea := 'Caja: '||rpad(p_nro_caja,4,' ');--||lpad(v_nom_usuario,30,' ');
  pag_imp.pr_imp_linea(v_resultado, v_linea, 1);

  --imprimo nro operación
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
  pag_imp.pr_imp_linea(v_resultado,'Moneda     : '||v_cod_moneda||'-'||v_des_moneda,1);
  pag_imp.pr_imp_linea(v_resultado,'Monto      : '||trim(to_char(v_monto,'999,999,999,999.99')),1);
  pag_imp.pr_imp_linea(v_resultado,upper(v_des_moneda)||' '||upper(v_des_monto)||'.-',1);

  pag_imp.pr_imp_linea(v_resultado,'Caja Envia : '||to_char(p_nro_caja)||'-'||v_cod_usuario,2);
  pag_imp.pr_imp_linea(v_resultado,'Nombre     : '||fue_obt_nom_usuario(v_cod_usuario),1);
  pag_imp.pr_imp_linea(v_resultado,'Sello/Firma: ',1);

  pag_imp.pr_imp_linea(v_resultado,'Caja Recibe: '||to_char(v_nro_caj_destino)||'-'||v_cod_usu_destino,11);
  pag_imp.pr_imp_linea(v_resultado,'Nombre     : '||fue_obt_nom_usuario(v_cod_usu_destino),1);
  pag_imp.pr_imp_linea(v_resultado,'Sello/Firma: ',1);

  -- imprimo el pie
  pag_imp.pr_imp_pie(v_resultado, 11);   -- linea antes
  v_linea := null;
  --v_linea := '----------------------------------------';
  pag_imp.pr_imp_linea(v_resultado, v_linea, 1);
  return(v_resultado);

end FUJ_IMP_COMPROBANTE_204;
/

