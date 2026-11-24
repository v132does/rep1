create or replace function it.FUJ_IMP_COMPROBANTE_218
  (p_cod_telegrama in number,
   p_cod_oficina   in number,
   p_nro_caja      in number)
 return varchar2 is
  --comprimido 40 de ancho
  v_ancho     	 	 number(3) := 40; -- ancho del reporte
  v_resultado 		 varchar2(4000) := null;
  v_linea     		 varchar2(200);
  v_fecha          date := SYSDATE;
  v_hora           varchar2(8) := to_char(sysdate,'hh24:mi:ss');
  --
  v_cod_moneda      varchar2(4);
  v_des_moneda      varchar2(100);
  v_monto           number(18,2);
  v_des_monto       varchar2(300);
 --
  v_nro_impresion number(10);
  v_nom_usuario varchar2(100);
  v_efectivo ge_movimientos.monto%type := 0; 
  v_nstro_bco ge_movimientos.monto%type := 0;  
  v_otro_bco ge_movimientos.monto%type := 0;  
  v_nom_cliente varchar2(1000);  

begin
  -- seteo la oficina
  pag_imp.pr_set_oficina(p_cod_oficina);
  -- seteo el ancho del reporte
  pag_imp.pr_set_ancho(v_ancho); -- ancho del comprobante
  --imprimir nro de impresión, x ahora no se enumeran
  v_nro_impresion := 0;
  Begin
    Select nvl(count(*),0)+1
      into v_nro_impresion
      from cj_movimientos
     where cod_tra_padre = 110
       and cod_mod_padre = 9
       and cod_mad_padre = 91
       and nro_documento = p_cod_telegrama;
  End;
  declare 
    cursor  mov is 
      select cod_transaccion, monto
        from ge_movimientos z
       where z.cod_usuario = user
         and z.cod_tra_padre =218
         and z.nro_documento = p_cod_telegrama
         and z.reversado = 'N'
         and z.nro_caja = p_nro_caja;
  begin
    Select a.cod_moneda, c.descripcion des_moneda, nom_completo
      into v_cod_moneda, v_des_moneda, v_nom_cliente
      from ba_monedas c, ba_personas b, ge_telegramas a
     where a.cod_telegrama = p_cod_telegrama
       and a.cod_moneda = c.cod_moneda
       and a.cod_persona = b.cod_persona;  
    for im in mov loop
        if im.cod_transaccion = 690 then
           v_efectivo := im.monto;
        elsif im.cod_transaccion = 606 then
           v_nstro_bco := im.monto;
        elsif im.cod_transaccion in (607,610,632) then
           v_otro_bco := im.monto;
        end if;          
    end loop;   
    v_monto := nvl(v_efectivo,0)+ nvl(v_nstro_bco,0) + nvl(v_otro_bco,0);
    v_des_monto := fue_obt_denominacion(v_monto);
  exception
    when no_data_found then
       return(v_resultado);
  end;

  pag_imp.pr_imp_cab_centrada(v_resultado,'* '||'COBRO DE MULTA - CHEQUES DEVUELTOS'||' *',null,1);

  -- imprimo la fecha y hora
  v_linea := 'Fecha: '||to_char(v_fecha,'dd/mm/yyyy')||'               '||v_hora;
  pag_imp.pr_imp_linea(v_resultado, v_linea, 2);
  -- Imprimo datos del cajero --ver si el usuario del movimiento = al del mov. de caja
  v_nom_usuario :=fue_obt_nom_usuario(user);
  if fug_obt_tip_implementacion = 1 then
    v_linea := 'Caja: '||rpad(p_nro_caja,4,' ');--||lpad(v_nom_usuario,30,' ');
  else
    v_linea := 'Caja: '||rpad(p_nro_caja,4,' ')||lpad(v_nom_usuario,30,' ');
  end if;
  pag_imp.pr_imp_linea(v_resultado, v_linea, 1);


  --imprimo nro operación
  if v_nro_impresion = 0 then
    v_linea := 'Numero: '||rpad(p_cod_telegrama,8,' ')||'                '||'Original';
    pag_imp.pr_imp_linea(v_resultado,v_linea,1);
  else
    v_linea := 'Numero: '||rpad(p_cod_telegrama,8,' ')||'       '||'Copia Nro.: '||lpad(v_nro_impresion,5,' ');
    pag_imp.pr_imp_linea(v_resultado,v_linea,1);
  end if;
  -- detalle de la operacion
  pag_imp.PR_IMP_LINEA(v_resultado,lpad('-',40,'-'),1);
  
  v_linea := 'Cliente: '||v_nom_cliente;
  pag_imp.pr_imp_linea(v_resultado,v_linea,2);
  pag_imp.pr_imp_linea(v_resultado,' ',1);
  -- Datos de la Cuenta
  if nvl(v_efectivo,0) > 0 then
    pag_imp.pr_imp_linea(v_resultado,'Efectivo       : '||v_cod_moneda||' '||lpad(to_char(v_efectivo,'9,999,999,999.99'),20,' '),1);
  end if;
  if nvl(v_nstro_bco,0) > 0 then
    pag_imp.pr_imp_linea(v_resultado,'Cheq.Ntro.Bco  : '||v_cod_moneda||' '||lpad(to_char(v_nstro_bco,'9,999,999,999.99'),20,' '),1);
  end if;
  if nvl(v_otro_bco,0) > 0 then
    pag_imp.pr_imp_linea(v_resultado,'Cheq.Otros Bcos: '||v_cod_moneda||' '||lpad(to_char(v_otro_bco,'9,999,999,999.99'),20,' '),1);
  end if;
  
  pag_imp.pr_imp_linea(v_resultado,'Total Cobrado  : '||v_cod_moneda||' '||lpad(to_char(v_monto,'9,999,999,999.99'),20,' '),2);

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

end FUJ_IMP_COMPROBANTE_218;
/

