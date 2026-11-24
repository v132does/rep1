create or replace procedure it.prg_gen_dat_cta_ganadora
is
  --Variables--
  v_cta_row  ge_cta_ganadora_tmp%rowtype;
  v_fec_actual    date := pag_cal.fu_obt_fec_actual(1);
  v_ano_cta_ganadora ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('ANO_CTA_GANADORA');
  v_ano_actual number(4) := to_number(to_char(v_fec_actual,'yyyy'));
  v_ano_desde number(4);
  v_mes_desde number(2);
  v_ano_hasta number(4);
  v_mes_hasta number(2);
  v_fec_auxiliar date;
  v_indice number;
  v_fec_desde date;
  v_fec_hasta date;
  v_fec_calculo date;
  v_exi_par_cta_gan varchar2(1) := 'N';
  v_ano_mes_desde number(6);
  v_ano_mes_hasta number(6);

  --Definicion de arreglos tipo vectores--
  type vec_char is table of varchar2(12) index by binary_integer;
  type vec_number is table of number index by binary_integer;

  --Definicion de Vectores--
  ano_mes  vec_number;
  promedio vec_number;
  cargo    vec_char;

  --Cursores--
  cursor c_det_cta_ganadora  is
   Select t.cod_persona, s.nro_cuenta, g.cod_moneda,
       g.cod_modalidad, s.cod_modulo, a.nom_completo  nombre,
       a.nro_documento, fue_obt_nom_usuario(c.cod_usu_oficial) gestor,
       fue_obt_des_oficina(fug_obt_ofi_usuario(c.cod_usu_oficial)) ofi_gestor,
       b.cod_paquete, b.descripcion,
       decode(t.estado, 'N', 'NORMAL', 'C', 'CANCELADO', t.estado) estado, t.fec_inicio
    from ge_paq_clientes t, ge_paq_cuentas s, ge_paquetes b, ge_cuentas g,
         ge_cta_clientes l, ba_personas a, ge_clientes c
   where exists (select 1
                   from ge_par_dinamicos d
                  where d.parametro = 'CTA_GAN'
                    and instr(d.val_parametro, ',' || s.cod_paquete || ',') > 0)
   and b.estado = 'A'
   and t.cod_paquete = s.cod_paquete
   and s.cod_paquete = b.cod_paquete
   and s.nro_cuenta = g.nro_cuenta
   and l.nro_cuenta = g.nro_cuenta
   and l.cod_persona = t.cod_persona
   and a.cod_persona = t.cod_persona
   and c.cod_persona = t.cod_persona;

  cursor c_sal_pro_ctacte is
  select a.ano, a.mes,
         to_number(trim(to_char(a.ano,'9999'))||trim(to_char(a.mes,'09'))) ano_mes,
         round(a.sal_acu_diario / a.can_dia_acumulado,2) sal_promedio
    from cc_sal_mensuales a
   where a.nro_cuenta = v_cta_row.nro_cuenta
     and (a.ano*100)+a.mes >= v_ano_mes_desde
     and (a.ano*100)+a.mes <= v_ano_mes_hasta
     order by 1,2;

   cursor c_sal_pro_vistas is
   select a.ano, a.mes,
         to_number(trim(to_char(a.ano,'9999'))||trim(to_char(a.mes,'09'))) ano_mes,
         round(a.sal_acu_diario / a.can_dia_acumulado,2) sal_promedio
    from ah_sal_mensuales a
   where a.nro_cuenta = v_cta_row.nro_cuenta
     and (a.ano*100)+a.mes >= v_ano_mes_desde
     and (a.ano*100)+a.mes <= v_ano_mes_hasta
   order by 1,2;

  cursor c_tie_car_ctacte is
  Select to_number(trim(to_char(xx.fecha,'yyyymm'))) ano_mes,
         decode(nvl(count(*),0),0,'N','S') tie_cargo
    from cc_movimientos_his xx
   where xx.nro_cuenta = v_cta_row.nro_cuenta
     and xx.fecha between v_fec_desde and v_fec_hasta
     and xx.cod_tra_padre = 3403
     and xx.reversado = 'N'
     and xx.estado = 'N'
   group by to_number(trim(to_char(xx.fecha,'yyyymm')));

  cursor c_tie_car_vistas is
  Select to_number(trim(to_char(xx.fecha,'yyyymm'))) ano_mes,
         decode(nvl(count(*),0),0,'N','S') tie_cargo
    from ah_movimientos_his xx
   where xx.nro_cuenta = v_cta_row.nro_cuenta
     and xx.fecha between v_fec_desde and v_fec_hasta
     and xx.cod_tra_padre = 3403
     and xx.reversado = 'N'
     and xx.estado = 'N'
   group by to_number(trim(to_char(xx.fecha,'yyyymm')));

begin
  -- Author  : Christian Leiva
  -- Created : 13/10/2016
  -- Purpose : Cabecera de Paquetes
  begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1;  end;
  execute immediate 'truncate table ge_cta_ganadora_tmp';

  --Analizar el parametro--
  if v_ano_cta_ganadora is null then
     v_ano_cta_ganadora := v_ano_actual;
     v_ano_hasta := v_ano_actual;
     v_mes_hasta := to_number(to_char(v_fec_actual,'mm'));
     select to_number(to_char(add_months(v_fec_actual,-13),'yyyy')),
            to_number(to_char(add_months(v_fec_actual,-13),'mm')),
            add_months(v_fec_actual,-13)
       into v_ano_desde, v_mes_desde, v_fec_desde
       from dual;
  else
     v_exi_par_cta_gan := 'S';
     v_ano_hasta := v_ano_cta_ganadora;
     v_mes_hasta := 12;
     v_fec_auxiliar := to_date('01/12/'||trim(to_char(v_ano_hasta)),'dd/mm/yyyy');
     select to_number(to_char(add_months(v_fec_auxiliar,-13),'yyyy')),
            to_number(to_char(add_months(v_fec_auxiliar,-13),'mm')),
            add_months(v_fec_auxiliar,-13)
       into v_ano_desde, v_mes_desde, v_fec_desde
       from dual;
  end if;

  v_fec_hasta := to_date('01/'||trim(to_char(v_mes_hasta,'09'))||'/'||trim(to_char(v_ano_hasta,'9999')),'dd/mm/yyyy');

  select add_months(v_fec_desde,-1)
    into v_fec_calculo
    from dual;
    
  --Calculo numerico de fechas desde y hasta--
  select to_number(to_char(v_fec_desde,'yyyymm')),
         to_number(to_char(v_fec_hasta,'yyyymm'))
    into v_ano_mes_desde, v_ano_mes_hasta
    from dual;

  for v_indice in 1..14 loop
      select add_months(v_fec_calculo,1)
        into v_fec_calculo
        from dual;
      ano_mes(v_indice) := to_number(to_char(v_fec_calculo,'yyyymm'));
  end loop;

  for d in c_det_cta_ganadora  loop
      --Carga de Variables--
      v_cta_row.cod_persona := d.cod_persona;
      v_cta_row.nombre      := d.nombre;
      v_cta_row.nro_documento := d.nro_documento;
      v_cta_row.gestor      := d.gestor;
      v_cta_row.ofi_gestor  := d.ofi_gestor ;
      v_cta_row.cod_paquete := d.cod_paquete;
      v_cta_row.descripcion := d.descripcion;
      v_cta_row.estado      := d.estado;
      v_cta_row.fec_inicio  := d.fec_inicio;
      v_cta_row.cod_persona := d.cod_persona;
      v_cta_row.nro_cuenta  := d.nro_cuenta;
      v_cta_row.cod_moneda  := d.cod_moneda;
      v_cta_row.des_modal   := fug_obt_des_modalidad(d.cod_modalidad) ;

      --Cerar - Inicializar los Vectores--
      for v_indice in 1..14 loop
          promedio(v_indice) := 0;
          cargo(v_indice) := null;
      end loop;
        
      --C<rga de Promedios y si tiene Cargos--
      if d.cod_modulo = 3 then
         for pro in c_sal_pro_vistas loop
             for v_indice in 1..14 loop
                 if ano_mes(v_indice) = pro.ano_mes then
                     promedio(v_indice) := pro.sal_promedio;
                    exit;
                 end if;
             end loop;
         end loop;

         for car in c_tie_car_vistas loop
             for v_indice in 1..14 loop
                 if ano_mes(v_indice) = car.ano_mes then
                     cargo(v_indice) := nvl(car.tie_cargo,'N');
                    exit;
                 end if;
             end loop;
         end loop;
      else
         for pro in c_sal_pro_ctacte loop
             for v_indice in 1..14 loop
                 if ano_mes(v_indice) = pro.ano_mes then
                     promedio(v_indice) := pro.sal_promedio;
                    exit;
                 end if;
             end loop;
         end loop;

         for car in c_tie_car_ctacte loop
             for v_indice in 1..14 loop
                 if ano_mes(v_indice) = car.ano_mes then
                     cargo(v_indice) :=  nvl(car.tie_cargo,'N');
                    exit;
                 end if;
             end loop;
         end loop;
      end if;

      --Carga de referencia del mes y año--
      v_cta_row.mes_pro_01 := ano_mes(1);
      v_cta_row.mes_pro_02 := ano_mes(2);
      v_cta_row.mes_pro_03 := ano_mes(3);
      v_cta_row.mes_pro_04 := ano_mes(4);
      v_cta_row.mes_pro_05 := ano_mes(5);
      v_cta_row.mes_pro_06 := ano_mes(6);
      v_cta_row.mes_pro_07 := ano_mes(7);
      v_cta_row.mes_pro_08 := ano_mes(8);
      v_cta_row.mes_pro_09 := ano_mes(9);
      v_cta_row.mes_pro_10 := ano_mes(10);
      v_cta_row.mes_pro_11 := ano_mes(11);
      v_cta_row.mes_pro_12 := ano_mes(12);
      v_cta_row.mes_pro_13 := ano_mes(13);
      v_cta_row.mes_pro_14 := ano_mes(14);

      --Carga saldo promedio--
      v_cta_row.sal_pro_01 := promedio(1);
      v_cta_row.sal_pro_02 := promedio(2);
      v_cta_row.sal_pro_03 := promedio(3);
      v_cta_row.sal_pro_04 := promedio(4);
      v_cta_row.sal_pro_05 := promedio(5);
      v_cta_row.sal_pro_06 := promedio(6);
      v_cta_row.sal_pro_07 := promedio(7);
      v_cta_row.sal_pro_08 := promedio(8);
      v_cta_row.sal_pro_09 := promedio(9);
      v_cta_row.sal_pro_10 := promedio(10);
      v_cta_row.sal_pro_11 := promedio(11);
      v_cta_row.sal_pro_12 := promedio(12);
      v_cta_row.sal_pro_13 := promedio(13);
      v_cta_row.sal_pro_14 := promedio(14);

      --Carga si tiene cargos--
      v_cta_row.tie_car_01 := nvl(cargo(1),'N');
      v_cta_row.tie_car_02 := nvl(cargo(2),'N');
      v_cta_row.tie_car_03 := nvl(cargo(3),'N');
      v_cta_row.tie_car_04 := nvl(cargo(4),'N');
      v_cta_row.tie_car_05 := nvl(cargo(5),'N');
      v_cta_row.tie_car_06 := nvl(cargo(6),'N');
      v_cta_row.tie_car_07 := nvl(cargo(7),'N');
      v_cta_row.tie_car_08 := nvl(cargo(8),'N');
      v_cta_row.tie_car_09 := nvl(cargo(9),'N');
      v_cta_row.tie_car_10 := nvl(cargo(10),'N');
      v_cta_row.tie_car_11 := nvl(cargo(11),'N');
      v_cta_row.tie_car_12 := nvl(cargo(12),'N');
      v_cta_row.tie_car_13 := nvl(cargo(13),'N');
      v_cta_row.tie_car_14 := nvl(cargo(14),'N');

      --Inserya en la tabla temporal--
      insert into ge_cta_ganadora_tmp values v_cta_row;
  end loop;

  --Eliminacion de Parametro--
  if nvl(v_exi_par_cta_gan,'N') = 'S' then
     delete from ge_par_dinamicos a
      where a.parametro = 'ANO_CTA_GANADORA';
  end if;
exception
      when others then
        raise_application_error(-20000,'Error en prg_gen_dat_cta_ganadora-'||sqlerrm);
end prg_gen_dat_cta_ganadora;
/

