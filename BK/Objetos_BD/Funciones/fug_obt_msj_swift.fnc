CREATE OR REPLACE FUNCTION IT.fug_obt_msj_swift ( p_fecha date default null ) RETURN typ_tab_snp_swift AS

/** Propósito: extraer datos del mje swift -- RABP-CNF-08-01-2015 **/

  v_tab         typ_tab_snp_swift := typ_tab_snp_swift();
  v_contador    NUMBER;
  v_linea       NUMBER;
  v_referencia  VARCHAR(20);
 
  CURSOR msj_swift(p_linea IN NUMBER, p_referencia IN CHAR) IS  -- Extraemos los datos del string
    select TRIM(SUBSTR(m.msj_swift,(INSTR(m.msj_swift,'/TERMFROM/', 1, p_linea)+10),INSTR(m.msj_swift,'/TERM/', 1, p_linea) - (INSTR(m.msj_swift,'/TERMFROM/', 1, p_linea)+11))) Plazo_de,
           TRIM(SUBSTR(m.msj_swift,(INSTR(m.msj_swift,'/TERM/', 1, p_linea)+6),INSTR(m.msj_swift,'/CURRENCY/', 1, p_linea) - (INSTR(m.msj_swift,'/TERM/', 1, p_linea)+7))) Plazo_a,
           TRIM(SUBSTR(m.msj_swift,(INSTR(m.msj_swift,'/CURRENCY/', 1, p_linea)+10),INSTR(m.msj_swift,'/DEPOSITVALUE/', 1, p_linea) - (INSTR(m.msj_swift,'/CURRENCY/', 1, p_linea)+11))) Moneda,
           m.fec_valor fecha,
           /*TRIM(SUBSTR(m.msj_swift,
                  (INSTR(m.msj_swift, '/DEPOSITVALUE/', 1, p_linea) + 14),
                  DECODE(INSTR(m.msj_swift, ':79:', 1, p_linea + 1), 
                         0,
                         INSTR(m.msj_swift, '-}', 1, 1),
                         INSTR(m.msj_swift, ':79:', 1, p_linea + 1)) - (INSTR(m.msj_swift, '/DEPOSITVALUE/', 1, p_linea) + 15)
                         ))Monto*/
           decode(SUBSTR(TRIM (SUBSTR(m.msj_swift,(INSTR(m.msj_swift, '/DEPOSITVALUE/', 1, p_linea) + 14))),
                         INSTR(SUBSTR(m.msj_swift,(INSTR(m.msj_swift, '/DEPOSITVALUE/', 1, p_linea) + 14)),',') +1, 1), 
                 chr(10),
                 SUBSTR(TRIM (SUBSTR(m.msj_swift,(INSTR(m.msj_swift, '/DEPOSITVALUE/', 1, p_linea) + 14))),1,
                        INSTR(SUBSTR(m.msj_swift,(INSTR(m.msj_swift, '/DEPOSITVALUE/', 1, p_linea) + 14)),',')-1),
                 SUBSTR(TRIM (SUBSTR(m.msj_swift,(INSTR(m.msj_swift, '/DEPOSITVALUE/', 1, p_linea) + 14))),1,
                        INSTR(SUBSTR(m.msj_swift,(INSTR(m.msj_swift, '/DEPOSITVALUE/', 1, p_linea) + 14)),',')+2)) Monto
      from ge_snp_mensajes m
     where m.cod_msj_swift  = 998
       and m.nro_referencia = p_referencia
       and m.fec_valor      = p_fecha;

BEGIN
  -- Hallamos la ultima referencia del dia  
  begin
    select nvl(max(t.nro_referencia),0)
      into v_referencia
      from GE_SNP_MENSAJES t
     where t.cod_msj_swift = 998
       and t.situacion     = 'V'
       and t.fec_valor     = p_fecha;
   exception
     when no_data_found then
       RETURN null;
     when others then
       RETURN null;
   end;

  -- Hallamos la cantidad de registros que estan concatenados en el string
  begin
    select LENGTH(t.msj_swift) - LENGTH(REPLACE(t.msj_swift, ':79:', ':79'))
      into v_linea
      from GE_SNP_MENSAJES t
     where t.cod_msj_swift  = 998
       and t.situacion      = 'V'
       and t.fec_valor      = p_fecha
       and t.nro_referencia = v_referencia;
   exception
     when no_data_found then
       RETURN null;
     when others then
       RETURN null;
   end;
   
  -- Recorremos de acuerdo a la cantidad de registros concatenados
  FOR v_contador IN 1..v_linea LOOP
    v_tab.extend();
     FOR i IN msj_swift(v_contador, v_referencia) LOOP -- Pasamos al cursor la numero de registro a extraer
         -- Cargamos la tabla
         v_tab(v_tab.count) := typ_reg_snp_swift(i.plazo_de, i.plazo_a, i.moneda, i.fecha, i.monto);
     END LOOP;
  END LOOP;

  RETURN v_tab;  -- Retornamos los datos de la tabla

END fug_obt_msj_swift;
/

