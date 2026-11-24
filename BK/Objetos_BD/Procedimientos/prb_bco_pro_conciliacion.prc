create or replace procedure it.prb_bco_pro_conciliacion (p_ano in number default null,
                                                      p_mes in number default null) is
v_mes number(2);
v_ano number(4);
v_existe_pro varchar2(1);
v_existe_bco varchar2(1);

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
--
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
   if (v_existe_bco = 'N') then
         raise_application_error(-20005,'Mes a Conciliar para procesadora no se encuentra cargado.'||chr(10)||
                                 'Mes: '||v_mes||chr(10)||'Año: '||v_ano);
   end if;
--
   if (v_existe_pro = 'N') then
      raise_application_error(-20005,'Mes a Conciliar para Banco no se encuentra cargado.'||chr(10)||
                                 'Mes: '||v_mes||chr(10)||'Año: '||v_ano);
   end if;
--
   update cb_mov_bco_clearing a
   set a.est_conciliado = 'S',
       a.ubicacion = 'Archivo de Infonet'
   where a.ano = v_ano
   and a.mes = v_mes
   and exists (select 0
              from cb_mov_procesadora b
              where b.nro_referencia = a.nro_referencia)
   and a.est_conciliado is null;

   update cb_mov_procesadora a
   set a.est_conciliado = 'S',
       a.ubicacion = 'Archivo del Banco'
   where a.ano = v_ano
   and a.mes = v_mes
   and exists (select 0
               from cb_mov_bco_clearing b
               where b.nro_referencia = a.nro_referencia)
   and a.est_conciliado is null
   and nvl(a.conciliable,'S') = 'S';
--

   update cb_mov_procesadora a
   set a.est_conciliado = 'S',
       a.ubicacion = 'Historico de GF'
   where a.ano = v_ano
   and a.mes = v_mes
   and a.cod_operacion not in (2,10,6,15,17,16,13)
   and a.cod_respuesta = 0
   and a.est_conciliado is null
   and exists (select 0
               from ah_movimientos_his b
               where b.nro_cuenta = a.nro_cuenta
               and b.hora = a.hora)
   and a.est_conciliado is null
   and upper(a.nom_entidad) like '%ATLAS%'
   and upper(a.raz_social) like '%ATLAS%'
   and a.conciliable = 'S';

end prb_bco_pro_conciliacion;
/

