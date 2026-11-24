create or replace function it.FUW_IMP_SUE_ERRORES(p_cod_ente in ge_entes.cod_ente%type,
                                               p_referencia in ge_pag_sueldos.nro_secuencia%type,
                                               p_linea in varchar2 default 'N') 
  return clob is
  v_retorno clob := '';
  v_can_sue_errores number;
  v_cont number := 0;
  -- movimientos de sueldos con error
  cursor c_sue_error is
     select x.nro_cuenta, substr(z.denominacion,1,40) denominacion, x.cod_moneda cod_moneda, x.monto,
            x.msj_error  
       from ge_cuentas z,ge_pag_sueldos_err x
      where x.cod_ente = p_cod_ente 
        and x.fec_proceso = paw_bce.v_fec_actual
        and nvl(x.nro_secuencia,0) = nvl(p_referencia,0)
        and to_char(x.nro_cuenta) = z.nro_cuenta;
begin
  pag_htm.v_texto := '';-- inicializo el texto
  -- buscamos si hubieron registros con error
  select nvl(count(0), 0)
    into v_can_sue_errores
    from ge_pag_sueldos_err x
   where x.cod_ente = p_cod_ente
     and x.fec_proceso = paw_bce.v_fec_actual
     and nvl(x.nro_secuencia,0) = nvl(p_referencia,0);
  -- desplegamos informacion de errores si las hubo
  if v_can_sue_errores > 0 then
    if p_linea = 'S' then
       pag_htm.pr_texto('<hr width=630>'); --dibuja una línea horizontal            
    end if;
    pag_htm.PR_TABLA('S',630,null,0); -- DEFINO LA TABLA
      pag_htm.PR_FILA('S'); -- ABRO LA FILA
      pag_htm.PR_COLUMNA('<font color="red">DETALLES NO ACREDITADOS POR ERROR</font>',NULL,'center','S'); -- agrego la columna etiqueta
      pag_htm.PR_FILA('N'); -- CIERRO LA FILA
    pag_htm.PR_TABLA('N'); -- CIERRO LA TABLA
    pag_htm.pr_texto('<hr width=630>'); --dibuja una línea horizontal  
    pag_htm.PR_TABLA('S',630,null,0); -- DEFINO LA TABLA
      pag_htm.PR_FILA('S'); -- ABRO LA FILA
      pag_htm.PR_COLUMNA('Cuenta',133,'left','S'); -- agrego la columna etiqueta
      pag_htm.PR_COLUMNA('Nombre de Cuenta',300,'left','S'); -- agrego la columna etiqueta
      pag_htm.PR_COLUMNA('&nbsp;&nbsp;Mon.',15,'left','S'); -- agrego la columna 
      pag_htm.PR_COLUMNA('Monto',180,'right','S'); -- agrego la columna 
      pag_htm.PR_FILA('N'); -- CIERRO LA FILA
    for reg in c_sue_error loop
      v_cont := v_cont + 1;
      if v_cont > 100 then
        v_retorno := v_retorno || pag_htm.v_texto;
        pag_htm.v_texto := null;
        v_cont := 0;
      end if;
      pag_htm.PR_FILA('S'); -- ABRO LA FILA
      pag_htm.PR_COLUMNA(reg.nro_cuenta,133,'left'); -- agrego la columna 
      pag_htm.PR_COLUMNA(reg.denominacion,300,'left'); -- agrego la columna           
      pag_htm.PR_COLUMNA('&nbsp;&nbsp;'||reg.cod_moneda,15,'left'); -- agrego la columna 
      pag_htm.PR_COLUMNA(to_char(reg.monto,'999,999,999,999.99'),180,'right'); -- agrego la columna 
      pag_htm.PR_FILA('N'); -- CIERRO LA FILA
      -- Motivo del Error.
      pag_htm.PR_FILA('S'); -- ABRO LA FILA
      pag_htm.PR_COLUMNA(null,133,'left'); -- agrego la columna 
      pag_htm.PR_COLUMNA('<b> Motivo: </b>'||reg.msj_error,300,'left'); -- agrego la columna           
      pag_htm.PR_FILA('N'); -- CIERRO LA FILA
    end loop;
    pag_htm.PR_TABLA('N'); -- CIERRO LA TABLA
  end if;
  v_retorno := v_retorno || pag_htm.v_texto;
  return v_retorno;
end FUW_IMP_SUE_ERRORES;
/

