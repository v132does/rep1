create or replace package body it.paw_log is

  function fu_obtieneCollection(p_type in varchar2)
   return varchar2 is
   v_nom_type varchar2(30);
  begin
    select o.elem_type_name
      into v_nom_type
      from all_coll_types o
    where type_name =  upper(p_type);
     return v_nom_type;
  exception
    when others then
      return null;
  end;

  procedure pr_retornaValoresTypes(p_type in varchar2) is

  v_sql        clob;
  v_error      varchar2(4000);
  v_collection varchar2(30);
  v_sep        varchar2(10):= '   ';
  v_sep_det    varchar2(10):= '  ';

  cursor types is
      select attr_name, attr_type_name
        from all_type_attrs o
       where o.type_name = upper(p_type)
       order by o.attr_no asc;

  cursor types_det is
      select attr_name, attr_type_name
        from all_type_attrs o
       where o.type_name = upper(v_collection)
       order by o.attr_no asc;

  begin
      v_sql := ' declare v_can_registros number(9):= 0; begin ';
      v_sql := v_sql|| '  dbms_output.put_line('||chr(39)||'<Respuesta>'||chr(39)||'); ';
      for c in types loop
        if c.attr_type_name in ('VARCHAR2','NUMBER') then
           v_sql := v_sql||
                    '  dbms_output.put_line('||chr(39)||'<'||c.attr_name||'> '||
                                               chr(39)||'|| paw_log.g_'||p_type||'.'||c.attr_name||'||'||chr(39)||' </'||c.attr_name||'>'||chr(39)|| '); ';

        elsif c.attr_type_name like 'TYP_LISTA%' or  c.attr_type_name like 'TYP_HB_LISTA%' then
            v_collection :=  fu_obtieneCollection(c.attr_type_name);
            v_sql := v_sql|| '  dbms_output.put_line('||chr(39)||'<Detalles>'||chr(39)||'); '||

             ' begin v_can_registros :=0; v_can_registros := nvl(paw_log.g_'||p_type||'.'||c.attr_name||'.count,0); '||
             ' exception when others then dbms_output.put_line('||chr(39)||'Cant. Reg. :'||chr(39)||'||v_can_registros); end; '||
             ' if v_can_registros > 0 then '||
             ' for idx in paw_log.g_'||p_type||'.'||c.attr_name||'.FIRST .. '||'paw_log.g_'||p_type||'.'||c.attr_name||'.LAST LOOP'||
                ' paw_log.g_'||v_collection|| ' := '||' paw_log.g_'||p_type||'.'||c.attr_name||'(idx);';
                v_sql := v_sql||'  dbms_output.put_line('||chr(39)||v_sep_det||'<'||chr(39)||'||fue_obt_denominacion(idx)||'||chr(39)||'>'||chr(39)||'); ';
                    for d in types_det loop
                      if d.attr_type_name not like 'TYP_HB_LISTA%' then
                          v_sql := v_sql||
                          '  dbms_output.put_line('||chr(39)||v_sep||'<'||d.attr_name||'> '||
                                                    chr(39)||'||paw_log.g_'||v_collection||'.'||d.attr_name||'||'||chr(39)||' </'||d.attr_name||'>'||chr(39)|| '); ';
                      end if;
                    end loop;
                 v_sql := v_sql||'  dbms_output.put_line('||chr(39)||v_sep_det||'</'||chr(39)||'||fue_obt_denominacion(idx)||'||chr(39)||'>'||chr(39)||'); ';
             v_sql := v_sql||' end loop; end if;';
             v_sql := v_sql|| '  dbms_output.put_line('||chr(39)||'</Detalles>'||chr(39)||'); ';
        end if;
      end loop;
      v_sql := v_sql|| '  dbms_output.put_line('||chr(39)||'</Respuesta>'||chr(39)||'); ';
      v_sql := v_sql||' end; ' ;
      sql_util.ejecute_dml(v_sql,v_error);

  exception
    when others then
      null;
  end;

  function fu_retornaValoresTypes(p_type in varchar2)
    return  clob is
  v_sql        clob;
  v_log        clob;
  v_collection varchar2(30);
  v_sep        varchar2(10):= '   ';
  v_sep_det    varchar2(10):= '  ';
  v_error      varchar2(4000);

  cursor types is
      select attr_name, attr_type_name
        from all_type_attrs o
       where o.type_name = upper(p_type)
       order by o.attr_no asc;

  cursor types_det is
      select attr_name, attr_type_name
        from all_type_attrs o
       where o.type_name = upper(v_collection)
       order by o.attr_no asc;

  begin
      v_sql := 'declare v_log clob; begin ';
      for c in types loop

        if c.attr_type_name in ('VARCHAR2','NUMBER') then
           v_sql := v_sql||
                    ' v_log := v_log ||'||chr(39)||'<'||c.attr_name||'>'||
                                          chr(39)||'|| paw_log.g_'||p_type||'.'||c.attr_name||'||'||chr(39)||' </'||c.attr_name||'>'||chr(39)|| '; ';
         elsif c.attr_type_name like 'TYP_LISTA%' or  c.attr_type_name like 'TYP_HB_LISTA%' then
            v_collection :=  fu_obtieneCollection(c.attr_type_name);
            v_sql := v_sql|| '  v_log := v_log ||'||chr(39)||'<<Detalles>>>'||chr(39)||'||chr(10); '||
            ' for idx in paw_log.g_'||p_type||'.'||c.attr_name||'.FIRST .. '||'paw_log.g_'||p_type||'.'||c.attr_name||'.LAST LOOP'||
                ' paw_log.g_'||v_collection|| ' := '||' paw_log.g_'||p_type||'.'||c.attr_name||'(idx);';
                v_sql := v_sql||'  v_log := v_log ||'||chr(39)||v_sep_det||'<<'||chr(39)||'||idx||'||chr(39)||'>>'||chr(39)||'||chr(10); ';
                    for d in types_det loop
                      v_sql := v_sql||
                      '  v_log := v_log ||'||chr(39)||v_sep||'<'||d.attr_name||'>'||
                                                      chr(39)||'||paw_log.g_'||v_collection||'.'||d.attr_name||'||'||chr(39)||' </'||d.attr_name||'>'||chr(39)|| '; ';
                    end loop;
             v_sql := v_sql||' end loop; ||chr(10);';
        end if;
      end loop;
      v_sql := v_sql||
      'paw_log.pr_setLog(v_log);'||
      ' end; ' ;
      sql_util.ejecute_dml(v_sql,v_error);
      return v_log;
  exception
    when others then
      return 'Error '||sqlerrm;
  end;

  procedure pr_logValoresTypes(p_type in varchar2,
                               p_generarLog in varchar2 default null,
                               p_canal      in varchar2 default null)
  is
  v_sql        clob;
  v_log        clob;
  v_collection varchar2(30);
  v_sep        varchar2(10):= '   ';
  v_sep_det    varchar2(10):= '  ';
  v_error      varchar2(4000);
  v_cod_canal  varchar2(3);
  PRAGMA AUTONOMOUS_TRANSACTION;
  cursor types is
      select attr_name, attr_type_name
        from all_type_attrs o
       where o.type_name = upper(p_type)
       order by o.attr_no asc;

  cursor types_det is
      select attr_name, attr_type_name
        from all_type_attrs o
       where o.type_name = upper(v_collection)
       order by o.attr_no asc;

  begin
      v_cod_canal  := SUBSTR(REGEXP_REPLACE(TRIM(p_canal), '([^[:alnum:]])', ''), 1, 3);
      v_sql := 'declare v_log clob; v_can_registros number(9):= 0;  begin ';
      v_sql := v_sql|| '  v_log := v_log ||'||chr(39)||'<Respuesta>'||chr(39)||'||chr(10); ';
      for c in types loop

        if c.attr_type_name in ('VARCHAR2','NUMBER') then
           v_sql := v_sql||
                    ' v_log := v_log ||'||chr(39)||'<'||c.attr_name||'>'||
                                          chr(39)||'|| paw_log.g_'||p_type||'.'||c.attr_name||'||'||chr(39)||' </'||c.attr_name||'> '||chr(39)|| '||chr(10); ';
        elsif c.attr_type_name like 'TYP_LISTA%' or  c.attr_type_name like 'TYP_HB_LISTA%' then
            v_collection :=  fu_obtieneCollection(c.attr_type_name);
            v_sql := v_sql|| '  v_log := v_log ||'||chr(39)||'<Detalles>'||chr(39)||'||chr(10); '||
            ' begin v_can_registros :=0; v_can_registros := nvl(paw_log.g_'||p_type||'.'||c.attr_name||'.count,0); '||
            ' exception when others then  v_log := v_log ||'||chr(39)||'Cant. Reg. '||'paw_log.g_'||p_type||'.'||c.attr_name ||':'||chr(39)||'||v_can_registros; end; '||
            ' if v_can_registros > 0 then '||

            ' for idx in paw_log.g_'||p_type||'.'||c.attr_name||'.FIRST .. '||'paw_log.g_'||p_type||'.'||c.attr_name||'.LAST LOOP'||
                ' paw_log.g_'||v_collection|| ' := '||' paw_log.g_'||p_type||'.'||c.attr_name||'(idx);';
                v_sql := v_sql||'  v_log := v_log ||'||chr(39)||v_sep_det||'<'||chr(39)||'||fue_obt_denominacion(idx)||'||chr(39)||'>'||chr(39)||'||chr(10); ';
                    for d in types_det loop
                      if  d.attr_type_name not like 'TYP_HB_LISTA%' then
                          v_sql := v_sql||
                          '  v_log := v_log ||'||chr(39)||v_sep||'<'||d.attr_name||'>'||
                                                          chr(39)||'||paw_log.g_'||v_collection||'.'||d.attr_name||'||'||chr(39)||' </'||d.attr_name||'>'||chr(39)||'||chr(10); ';
                      end if;
                    end loop;
                v_sql := v_sql||'  v_log := v_log ||'||chr(39)||v_sep_det||'</'||chr(39)||'||fue_obt_denominacion(idx)||'||chr(39)||'>'||chr(39)||'||chr(10); ';
             v_sql := v_sql||' end loop; end if;';
             v_sql := v_sql|| '  v_log := v_log ||'||chr(39)||'</Detalles>'||chr(39)||'||chr(10); ';
             v_sql := v_sql|| '  v_log := v_log ||'||chr(39)||'</Respuesta>'||chr(39)||'||chr(10); ';
        end if;
      end loop;
      v_sql := v_sql||
      ' paw_log.pr_setLog(v_log);'||
      ' end; ' ;

      sql_util.ejecute_dml(v_sql,v_error);
      v_log := paw_log.fu_getLog;
       begin
        insert into bw_log_homebanking (pedido,respuesta) values(p_generarLog, v_error||paw_log.fu_getLog());
        commit;
        end;
  exception
    when others then
      null;
  end;

  function fu_getLog
    return  clob is
  begin
    return paw_log.g_log;
  end;

  procedure pr_setLog(p_log in clob) is
  begin
    paw_log.g_log := p_log;
  end;

  function fu_generarLog
    return varchar2 is
      v_linea    VARCHAR2(1000);
      v_paquete  VARCHAR2(1000);
      v_llamador VARCHAR2(1000);
      v_duenho   VARCHAR2(1000);
  begin
      OWA_UTIL.WHO_CALLED_ME(v_duenho, v_paquete, v_linea, v_llamador);
      return v_paquete || '.' || v_linea || sys_context('USERENV', 'ACTION') || ' Userid:' || sys_context('USERENV', 'SESSION_USER') || ' Ip:' || sys_context('USERENV', 'IP_ADDRESS') || ' isDBA:' || sys_context('USERENV', 'ISDBA') ;
  end;

end paw_log;
/

