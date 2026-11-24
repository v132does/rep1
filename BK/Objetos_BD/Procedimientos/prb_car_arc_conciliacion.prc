create or replace procedure it.prb_car_arc_conciliacion (p_ano in number default null,
                                                      p_mes in number default null) is
--inserta el archivo del temporal a los de conciliacion
v_mes number(2);
v_ano number(4);
v_existe_pro varchar2(1);
v_existe_bco varchar2(1);
v_existe_sal varchar2(1);
v_fecha_control_pro varchar2(6);
v_fecha_control_bco varchar2(6);

begin
if p_ano is null then
   v_ano := fug_obt_pardinamico('ANO_CONCILIACION');
else
   v_ano := p_ano;
end if;

if p_mes is null then
   v_mes := fug_obt_pardinamico('MES_CONCILIACION');
else
   v_mes := p_mes;
end if;
--Update de table del bco clearin para tomar los valore del campo arc_texto,
--se hizo asi pues se necesita cargar la cabecera des este archivo.
update cb_mov_bco_clearing_tmp g
set g.cod_sucursal = substr(g.arc_texto,1,3),
    g.nro_cuenta = to_char(to_number(substr(g.arc_texto,4,9))),
    g.fec_valor = to_date(substr(g.arc_texto,13,8),'yyyymmdd'),
    g.fec_contable = to_date(substr(g.arc_texto,21,8),'yyyymmdd'),
    g.cod_movimiento = substr(g.arc_texto,29,3),
    g.importe = round(to_number(substr(g.arc_texto,32,15))/100),
    g.tipo = substr(g.arc_texto,47,1),
    g.concepto = substr(g.arc_texto,48,29),
    g.nro_referencia = substr(g.arc_texto,77,9),
    g.mes = substr(g.arc_texto,17,2),
    g.ano = substr(g.arc_texto,13,4)
where length(g.arc_texto) > 47;
--
update cb_mov_bco_clearing_tmp g
set g.ano = fug_obt_pardinamico('ANO_CONCILIACION'),
    g.mes = fug_obt_pardinamico('MES_CONCILIACION')
where length(g.arc_texto) = 47;
--
delete from cb_mov_bco_clearing_tmp where length(arc_texto) < 47;
--
commit;
--
   begin
      select distinct(lpad((a.mes||a.ano),6,0))
      into v_fecha_control_pro
      from cb_mov_procesadora_tmp a;
   exception
   when too_many_rows then
      raise_application_error(-20001,'Existe mas de un mes en el archivo de la procesadora. Verifique...');
   end;
--
   begin
      select distinct(lpad((a.mes||a.ano),6,0))
      into v_fecha_control_bco
      from cb_mov_bco_clearing_tmp a;
   exception
   when too_many_rows then
       raise_application_error(-20002,'Existe mas de un mes en el archivo del Banco. Verifique...');
   end;
--
   select decode(count(*),0,'N','S')
   into v_existe_bco
   from cb_mov_bco_clearing_tmp a
   where a.mes = v_mes
   and a.ano = v_ano;
--
   select decode(count(*),0,'N','S')
   into v_existe_pro
   from cb_mov_bco_clearing_tmp a
   where a.mes = v_mes
   and a.ano = v_ano;
--
   if (v_existe_pro = 'N') then
      raise_application_error(-20003,'Meses Diferentes '||chr(10)||
                              'ARCHIVO PROCESADORA = ' ||v_fecha_control_pro||chr(10)||
                              'MES A CONCILIAR = '||v_mes||v_ano);
   end if;

--
   if (v_existe_bco = 'N') then
      raise_application_error(-20003,'Meses Diferentes '||chr(10)||
                              'ARCHIVO BANCO = ' ||v_fecha_control_pro||chr(10)||
                              'MES A CONCILIAR = '||v_mes||v_ano);
   end if;
--
   if v_fecha_control_pro <> v_fecha_control_bco then
      raise_application_error(-20003,'Meses diferente para archivo de Banco: '||v_fecha_control_bco
      ||' Procesadora: ' ||v_fecha_control_pro);
   end if;
-- Fin de control de tablas temporales
--
-- Control de tablas de conciliacion
   select decode(count(*),0,'N','S')
   into v_existe_bco
   from cb_mov_bco_clearing a
   where a.mes = v_mes
   and a.ano = v_ano;
--
   select decode(count(*),0,'N','S')
   into v_existe_pro
   from cb_mov_procesadora a
   where a.mes = v_mes
   and a.ano = v_ano;
--
   if (v_existe_pro = 'S') then
      raise_application_error(-20004,'Mes ya cargado para la procesadora.' ||chr(10)||
                              'Sólo para conciliar el parametro CARGA ARCHIVOS CONCILIACION debe ser N');
   end if;
--
   if (v_existe_bco = 'S') then
      raise_application_error(-20004,'Mes ya cargado para el banco.'||chr(10)||
                              'Sólo para conciliar el parametro CARGA ARCHIVOS CONCILIACION debe ser N');
   end if;
--
-- Control de tablas de conciliacion historicas
   select decode(count(*),0,'N','S')
   into v_existe_bco
   from cb_mov_bco_clearing_his a
   where a.mes = v_mes
   and a.ano = v_ano;
--
   select decode(count(*),0,'N','S')
   into v_existe_pro
   from cb_mov_procesadora_his a
   where a.mes = v_mes
   and a.ano = v_ano;
--
   if (v_existe_pro = 'S') then
      raise_application_error(-20004,'Mes ya cargado para la procesadora.' ||chr(10)||
                              'Sólo para conciliar el parametro CARGA ARCHIVOS CONCILIACION debe ser N');
   end if;
--
   if (v_existe_bco = 'S') then
      raise_application_error(-20004,'Mes ya cargado para el banco.'||chr(10)||
                              'Sólo para conciliar el parametro CARGA ARCHIVOS CONCILIACION debe ser N');
   end if;
--


   insert into cb_mov_bco_clearing c
                (c.cod_sucursal,c.nro_cuenta,c.fec_valor,c.fec_contable,
                c.cod_movimiento,c.importe, c.tipo,c.concepto,c.nro_referencia,
                c.est_conciliado,c.mes,c.ano)
                (select d.cod_sucursal,d.nro_cuenta,d.fec_valor,d.fec_contable,
                d.cod_movimiento,d.importe,d.tipo,d.concepto,d.nro_referencia,
                d.est_conciliado,d.mes,d.ano
                from cb_mov_bco_clearing_tmp d);

   insert into cb_mov_procesadora e
                (e.nro_cuenta,e.adherente,emision,e.nom_entidad,e.nom_cliente,e.ban_credito,
                 e.nro_atm_caja,e.nom_comercio,e.monto,e.cod_moneda,e.fecha,e.hora,e.cod_respuesta,
                 e.ind_conclusion,e.nro_referencia,e.raz_social,e.cod_operacion,e.des_operacion,
                 e.est_conciliado,e.mes,ano,e.fec_hor_movimiento)
                (select f.nro_cuenta,f.adherente,f.emision,f.nom_entidad,f.nom_cliente,f.ban_credito,
                 f.nro_atm_caja,f.nom_comercio,f.monto,f.cod_moneda,f.fecha,f.hora,f.cod_respuesta,
                 f.ind_conclusion,f.nro_referencia, f.raz_social,f.cod_operacion,f.des_operacion,
                 f.est_conciliado,f.mes,f.ano,to_date(to_char(f.fecha,'ddmmyyyy')||' '||f.hora,'ddmmyyyy hh24:mi:ss')
                 from cb_mov_procesadora_tmp f);
--Para los no conciliables
   update cb_mov_procesadora a
      set a.conciliable = 'N'
    where a.cod_respuesta <> 0 or
          a.ind_conclusion <> 'S' or
          a.cod_operacion in (2,10,6,15,17,16,13);
--Para los conciliables
   update cb_mov_procesadora a
      set a.conciliable = 'S'
    where a.cod_respuesta = 0
      and a.ind_conclusion = 'S'
      and a.cod_operacion not in (2,10,6,15,17,16,13);
--Para los Saldos Mensuales de Banco
   select decode(count(*),0,'N','S')
   into v_existe_sal
   from cb_sal_bco_clearing a
   where a.ano = fug_obt_pardinamico('ANO_CONCILIACION')
   and a.mes = fug_obt_pardinamico('MES_CONCILIACION');

if v_existe_sal = 'N' then
   insert into cb_sal_bco_clearing cl
   (cl.ano,cl.mes,cl.nro_cuenta,cl.sal_anterior,cl.sal_actual)
   (select fug_obt_pardinamico('ANO_CONCILIACION'),fug_obt_pardinamico('MES_CONCILIACION'),
    to_char(to_number(substr(a.arc_texto,4,9))) nro_cuenta,
    round(to_number(substr(a.arc_texto,32,15))/100) * decode(substr(a.arc_texto,47,1),'P',1,-1),
    round(to_number(substr(a.arc_texto,16,15))/100) * decode(substr(a.arc_texto,31,1),'P',1,-1)
    from cb_mov_bco_clearing_tmp a
    where length(a.arc_texto) = 47);
else
    update cb_sal_bco_clearing cl
    set cl.sal_anterior = (select round(to_number(substr(a.arc_texto,32,15))/100) * decode(substr(a.arc_texto,47,1),'P',1,-1)
                             from cb_mov_bco_clearing_tmp a
                            where length(a.arc_texto) = 47
                              and a.ano = cl.ano
                              and a.mes = cl.mes),
    cl.sal_actual = (select round(to_number(substr(a.arc_texto,16,15))/100) * decode(substr(a.arc_texto,31,1),'P',1,-1)
                       from cb_mov_bco_clearing_tmp a
                      where length(a.arc_texto) = 47
                        and a.ano = cl.ano
                        and a.mes = cl.mes)
    where cl.ano = fug_obt_pardinamico('ANO_CONCILIACION')
    and cl.mes = fug_obt_pardinamico('MES_CONCILIACION');

end if;
end;
/

