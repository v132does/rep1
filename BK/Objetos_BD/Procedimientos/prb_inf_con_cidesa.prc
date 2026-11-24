create or replace procedure it.prb_inf_con_cidesa( p_tipo varchar2 -- Tipo de informe a generar( D=Diario, M=Mensual, Q=Quincenal )
                                               )  is
  --Variables--
  v_fecha         date;
  v_fec_ini       date;
  v_fec_fin       date;
  v_fec_anterior  date;
  v_cod_banco     cc_cta_bancarias.cod_banco%type;
  v_nro_cuenta    cc_cta_bancarias.nro_cuenta%type;
  v_ref_mov       cb_inf_con_tmp.ref_movimiento%type;
  --Cursor para traer datos de Movimientos--
   cursor c_contabilidad is
      SELECT m.nro_cuenta nro_cuenta,
             m.concepto concepto,
             m.monto monto,
             m.cod_moneda,
             m.fecha,
             m.hora,
             m.nro_secuencia,
             m.cod_usuario
        FROM cc_movimientos_his m, ge_transacciones t
       WHERE m.cod_modulo = t.cod_modulo
         AND m.cod_modalidad = t.cod_modalidad
         AND m.cod_transaccion = t.cod_transaccion
         AND m.cod_modulo = 4
         AND m.cod_modalidad = 45
         AND m.reversado = 'N'
         AND nvl(m.monto, 0) <> 0
         AND m.nro_cuenta in( select distinct a.nro_cuenta
                                from cb_inf_con_tmp a );  
  --Cursor para traer datos de Extractos--
  cursor c_swift is
      select a.nro_cuenta nro_cuenta,
             a.ref_movimiento ref_movimiento,
             a.monto monto,
             a.cod_moneda,
             a.nro_ref_externa,
             a.nro_secuencia
        from cb_inf_con_tmp a
       where a.libro = 'S'
         and a.nro_cuenta = v_nro_cuenta
         and (a.ref_movimiento LIKE '%'||v_ref_mov||'%' OR
             a.nro_documento LIKE '%'||v_ref_mov||'%');

  --Funcion para obtener el codigo de banco--
  function lf_obt_cod_banco( p_nro_cuenta cc_cta_bancarias.nro_cuenta%type ) return cc_cta_bancarias.cod_banco%type is
    v_result cc_cta_bancarias.cod_banco%type;
  begin
    select cod_banco
      into v_result
      from cc_cta_bancarias
     where nro_cuenta = p_nro_cuenta;
    return v_result;
  exception
    when no_data_found then
      v_result := null;
      return v_result;
    when others then
      raise_application_error(-20000, 'Error al obtener código del Banco correspondiente a la cuenta '||p_nro_cuenta);
  end;

begin

  if p_tipo = 'D' then
    --Busca la fecha actual del balance cerrado 
    --select max(fecha) into v_fecha from cb_sal_oficinas_dia d; 
    --Obtenemos la fecha actual del sistema de contabilidad--
    --v_fecha := pag_cal.FU_OBT_FEC_ACTUAL(2);
    --Trae la ultima fecha del balance -- CN: 19/05/2015
    v_fecha := pag_cal.FU_OBT_FEC_ANTERIOR(2);
    --Obtenemos la fecha hábil anterior
    select pag_cal.FU_OBT_FEC_ANT_HAB (v_fecha,31,1)
      into v_fec_anterior
      from dual;
    v_fec_ini := v_fecha;
    v_fec_fin := v_fecha;
  elsif p_tipo = 'M' then
    --Trae la fecha de fin de mes anterior..
    select pag_cal.FU_OBT_FEC_ANT_HAB (x.pri_dia_mes,31,1)
      into v_fec_fin
      from ( select f.pri_dia_mes
               from ge_calendarios f
              where f.cod_modulo=2 ) x;
    --v_fec_fin := to_date('31/03/2015','dd/mm/yyyy'); --PARA PRUEBAS              
    --Fecha inicial a partir de la fecha fin
    select to_date('01/'||to_char(v_fec_fin,'mm/yyyy'),'dd/mm/yyyy')
      into v_fec_ini
      from dual;
    --Busca la ultima fecha del mes anterior
    select pag_cal.FU_OBT_FEC_ANT_HAB (v_fec_ini,31,1)
      into v_fec_anterior
      from dual;
  elsif p_tipo = 'Q' then
    --Obtenemos la fecha actual del sistema de contabilidad--
    --v_fecha := pag_cal.FU_OBT_FEC_ACTUAL(2);
    --Trae la ultima fecha del balance -- CN: 19/05/2015
    v_fecha:=pag_cal.FU_OBT_FEC_ANTERIOR(2);
    --Trae la ultima fecha del balance
    v_fec_fin:=pag_cal.FU_OBT_FEC_ANTERIOR(2);
    --Fecha inicial a partir de la fecha actual
    select to_date('01/'||to_char(v_fecha,'mm/yyyy'),'dd/mm/yyyy')
      into v_fec_ini
      from dual;
    --Busca la ultima fecha del mes anterior
    select pag_cal.FU_OBT_FEC_ANT_HAB (v_fec_ini,31,1)
      into v_fec_anterior
      from dual;
  else
    raise_application_error(-20000, 'Tipo de Informe incorrecto.');
  end if;

  execute immediate 'truncate table cb_inf_con_tmp';

  --Extracto--150807
  /*RE DE-1015 Se agrega el campo observacion concatenado el campo descripcion, solo se obtiene
  el valor del TAG BEN: del campo descripcion*/
  execute immediate 'insert into cb_inf_con_tmp
    SELECT ''S'' libro,
           c.nro_cuenta nro_cuenta,
           c.cod_moneda cod_moneda,
           d.nro_documento nro_documento,
           d.tip_movimiento tipo,
           d.monto monto,
           (d.ref_movimiento||''/''||substr(d.descripcion,1,10)) ref_movimiento,
           d.monto cta_monto,
           0 mov_monto,
           decode(d.tip_movimiento,''C'', d.monto, 0) credito,
           decode(d.tip_movimiento, ''D'', d.monto, 0) debito,
           d.nro_orden nro_secuencia,
           c.fec_mensaje fecha,
           NULL hora,
           NULL cod_usuario,
           NULL mov_tipo,
           NULL cod_modulo,
           NULL cod_modalidad,
           null cod_rubro,
           d.nro_ref_externa nro_ref_externa,
           d.nro_conciliacion nro_conciliacion,
           null ref_con_automatica,
           trim(replace(d.observacion||'' ''||substr(d.descripcion,
                                 decode(instr(d.descripcion,''BEN:''),0,0,
                                        instr(d.descripcion,''BEN:'')
                                        ),
                                 decode(instr(d.descripcion,''BEN:''),0,0,
                                        (length(d.descripcion)-instr(d.descripcion,''BEN:''))+1
                                        )
                                 ),'','',''-''))
      FROM ge_ext_swift c, ge_ext_swift_det d
     WHERE c.nro_ref_externa = d.nro_ref_externa
       AND c.fec_mensaje between '||''''||to_char(v_fec_ini,'dd/mm/yyyy')||''''||
     ' AND '||''''||to_char(v_fec_fin,'dd/mm/yyyy')||'''';

  --Movimientos--
  execute immediate 'insert into cb_inf_con_tmp
    SELECT ''N'' libro,
           m.nro_cuenta nro_cuenta,
           m.cod_moneda cod_moneda,
           to_char(m.nro_documento) nro_documento,
           decode(t.tipo, NULL, m.tip_mov_rubro, t.tipo) tipo,
           m.monto monto,
           m.concepto ref_movimiento,
           0 cta_monto,
           m.monto mov_monto,
           decode(decode(t.tipo, NULL, m.tip_mov_rubro, t.tipo), ''C'', m.monto, 0) credito,
           decode(decode(t.tipo, NULL, m.tip_mov_rubro, t.tipo), ''D'', m.monto, 0) debito,
           m.nro_secuencia nro_secuencia,
           m.fecha fecha,
           m.hora hora,
           m.cod_usuario cod_usuario,'||
           '''H'''||' mov_tipo,
           m.cod_modulo cod_modulo,
           m.cod_modalidad cod_modalidad,
           m.cod_rubro cod_rubro,
           NULL nro_ref_externa,
           m.nro_conciliacion nro_conciliacion,
           null ref_con_automatica,
           null observacion
      FROM cc_movimientos_his m, ge_transacciones t
     WHERE m.cod_modulo = t.cod_modulo(+)
       AND m.cod_modalidad = t.cod_modalidad(+)
       AND m.cod_transaccion = t.cod_transaccion(+)
       AND m.cod_modulo = 4
       AND m.cod_modalidad = 45
       AND m.reversado = ''N''
       AND nvl(m.monto, 0) <> 0
       AND m.nro_cuenta is not null
       AND m.fecha between '||''''||to_char(v_fec_ini,'dd/mm/yyyy')||''''||
     ' AND '||''''||to_char(v_fec_fin,'dd/mm/yyyy')||'''';

   --commit;

   for j in c_contabilidad loop
     v_nro_cuenta := j.nro_cuenta;
     v_cod_banco := lf_obt_cod_banco(v_nro_cuenta);
     if v_cod_banco = 285 then
       v_ref_mov := substr(substr(j.concepto, instr(j.concepto, '//') + 2,
                                  instr(substr(j.concepto, instr(j.concepto, '//')+ 2), '//') - 1),3);
     else
       v_ref_mov := substr(j.concepto, instr(j.concepto, '//') + 2,
                           instr(substr(j.concepto, instr(j.concepto, '//') + 2), '//') - 1); --substr(j.concepto, instr(j.concepto, '//') + 2, instr(j.concepto, '//') - 2);
     end if;


     if v_ref_mov is null then
       v_ref_mov := 'ºº';
     end if;

     for i in c_swift loop
       if i.monto = j.monto then
         --Extracto--
         update cb_inf_con_tmp a
            set a.ref_con_automatica = v_ref_mov
          where a.nro_cuenta = i.nro_cuenta
            and a.libro = 'S'
            and a.cod_moneda = i.cod_moneda
            and a.monto = i.monto
            and nro_ref_externa = i.nro_ref_externa
            and nro_secuencia = i.nro_secuencia;
         --Movimientos--
         update cb_inf_con_tmp a
            set a.ref_con_automatica = v_ref_mov
          where a.nro_cuenta = j.nro_cuenta
            and a.libro = 'N'
            and a.cod_moneda = j.cod_moneda
            and a.monto = j.monto
            and fecha = j.fecha
            and hora = j.hora
            and nro_secuencia = j.nro_secuencia
            and cod_usuario = j.cod_usuario;
       end if;
     end loop;
   end loop;

exception
  when others then
    Raise_application_error(-20000, 'Error al Generar los datos para el Informe de Conciliacion de Cuentas Corresponsal. '||sqlerrm);
end;
/

