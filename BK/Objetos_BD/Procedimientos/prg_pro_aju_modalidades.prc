CREATE OR REPLACE PROCEDURE IT.PRG_PRO_AJU_MODALIDADES IS

  cursor cta is
    select a.*
      from ge_movimientos a
     where a.cod_modulo   in (3, 4, 5, 6)
       and a.nro_cuenta   is not null
       and a.cod_usuario <> 'XPY8512'
       and not exists (select 1
                         from ge_cuentas aa
                        where aa.nro_cuenta    = a.nro_cuenta
                          and aa.cod_modulo    = a.cod_modulo
                          and aa.cod_modalidad = a.cod_modalidad);
                          
  --DYDMR-5614 12/2016
  cursor c_ver is
    select m.fecha,
           m.hora,
           m.cod_usuario,
           m.nro_secuencia,
           m.cod_rubro,
           m.cod_moneda
      from ge_movimientos m
     where m.cod_rubro is not null
       and ((not exists (select 0
                           from cb_rubros b
                          where b.cod_rubro = m.cod_rubro
                            and b.cod_moneda = m.cod_moneda))  OR
           (m.cod_rubro like '11120%'
       and m.cod_modalidad in (31,41)
       and m.nro_cuenta is not null ));

  --DYDMR-15272 - DR - 05.2021
  cursor c_ofic is
    select g.*
      from ge_movimientos a, pr_cta_prestamos g
     where a.nro_cuenta = g.nro_cuenta
       and a.cod_oficina <> g.cod_oficina;

  v_modulo    ge_cta_clientes.cod_modulo%type;
  v_modalidad ge_cuentas.cod_modalidad%type;

begin
  begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
  end;

  for c in cta loop
    dbms_output.put_line('Mov. Ori. Cuenta: '||c.nro_cuenta||'Modulo: '||c.cod_modulo||'Modalidad: '||c.cod_modalidad);
  
    select gc.cod_modulo, gc.cod_modalidad
      into v_modulo, v_modalidad
      from ge_cuentas gc
     where gc.nro_cuenta = c.nro_cuenta;
  
    dbms_output.put_line('Mov. Nue. Cuenta: '||c.nro_cuenta||'Modulo: '||v_modulo||'Modalidad: '||v_modalidad);
  
    update ge_movimientos gm
       set gm.cod_modulo    = v_modulo,
           gm.cod_modalidad = v_modalidad
     where gm.fecha       = c.fecha
       and gm.hora        = c.hora
       and gm.cod_usuario = c.cod_usuario
       and gm.nro_cuenta  = c.nro_cuenta;
  end loop;
  
  for rec in c_ver loop    
      dbms_output.put_line('Mov. con rubro invalido,Fecha: '||to_char(rec.fecha,'dd/mm/yyyy')||' Hora: '||rec.hora||' Usu: '||
                           rec.cod_usuario ||' Sec.: '||rec.nro_secuencia);
      
      update ge_movimientos g
         set g.cod_rubro = null,
             g.referencia = null,
             g.tip_mov_rubro = null
       where g.fecha = rec.fecha
         and g.hora = rec.hora
         and g.cod_usuario = rec.cod_usuario
         and g.nro_secuencia = rec.nro_secuencia
         and g.cod_rubro = rec.cod_rubro
         and g.cod_moneda = rec.cod_moneda;
      exit when c_ver%notfound;
  end loop;
  
  for dr in c_ofic loop    
      dbms_output.put_line('Mov. con Oficina Incorrecta ,Cuenta: '||dr.nro_cuenta||' Oficina: '||dr.cod_oficina);
      
      update ge_movimientos x
         set x.cod_oficina = dr.cod_oficina
       where x.nro_cuenta = dr.nro_cuenta
         and x.cod_oficina <> dr.cod_oficina;
  end loop;

exception
  when others then
    raise_application_error(-20000, 'Error al actualizar movimiento ' || sqlerrm);
end;
/

