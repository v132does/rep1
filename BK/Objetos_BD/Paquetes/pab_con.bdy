CREATE OR REPLACE PACKAGE BODY IT.PAB_CON is

/*
Paquete de conciliacion de rubros contables
Codificado por Simgia SRL - Mayo 2011
*/

-- Contador de conciliaciones, se incrementa en cada proceso por rubro
v_cuadre number(10) := 0;

-- Proceimiento principal de Conciliaciones, 
-- llama al procesos de conciliacion de cada rubro cargado con estado activo
PROCEDURE PR_GEN_CONCILIACION IS
  cursor c_rubros is
   SELECT distinct a.cod_rubro
        from  cb_con_rubros a
        where a.estado='A'; 
 BEGIN
    for rub in c_rubros loop 
        PR_GEN_RUB_CONCILIACION(rub.cod_rubro);
    end loop;
 EXCEPTION
     WHEN OTHERS THEN
       RAISE_APPLICATION_ERROR(-20000,'ERROR EN PR_GEN_CONCILIACION: '||sqlerrm);
 END;

--Genera conciliacion de un rubro dado, ejecutando los procesos configurados para cada rubro
PROCEDURE PR_GEN_RUB_CONCILIACION(v_cod_rubro varchar2) is
  v_proceso varchar2(50);
  v_pro_orden number;
  v_str_parametros long;
  v_parametro long;
  v_procesar long;
  --cursor de procesos
  cursor c_procesos is
   SELECT c.orden,b.cod_proceso,b.nom_proceso
        from  cb_con_rubros a, cb_con_procesos b, cb_con_rub_procesos c
        where a.cod_rubro=v_cod_rubro
        and a.cod_rubro=c.cod_rubro
        and b.cod_proceso=c.cod_proceso
        order by c.orden asc
        ; 
  --cursor de parametros 
  cursor c_parametros is
    SELECT b.cod_proceso,c.orden pro_orden,e.cod_parametro, d.orden par_orden, e.valor,d.tipo
       from  cb_con_rubros a, cb_con_procesos b, cb_con_rub_procesos c, cb_con_parametros d, cb_con_pro_parametros e
        where a.cod_rubro=v_cod_rubro
        and a.cod_rubro=c.cod_rubro
        and a.cod_rubro=e.cod_rubro
        and b.cod_proceso=c.cod_proceso
        and d.cod_proceso = c.cod_proceso
        and d.cod_parametro = e.cod_parametro
        and e.orden = c.orden
        order by c.orden asc, d.orden; 
     
  BEGIN
    v_cuadre:=1; --inicializa nro secuencial de conciliación para cada rubro
    for proc in c_procesos loop 
        v_proceso := proc.nom_proceso;
        v_pro_orden := proc.orden;
        v_str_parametros := null;
        v_parametro := null;
        
        -- se arma string de parametros
        for para in c_parametros loop
            if proc.cod_proceso=para.cod_proceso and proc.orden=para.pro_orden then
               if v_str_parametros is not null then
                  v_str_parametros := v_str_parametros || CHR(44);
               end if;
               if para.tipo = 'NUMBER' then
                  v_parametro := para.valor;
               else
                  v_parametro := replace(para.valor,CHR(39),CHR(39)||CHR(39));
                  v_parametro := '''' || v_parametro || '''';
               end if;
               v_str_parametros := v_str_parametros || v_parametro;    
               --dbms_output.put_line(para.valor);       
            end if;
         end loop;         
         --se ejecuta el proceso
         v_procesar := 'BEGIN ' || v_proceso || ' (' || v_str_parametros || '); END;';
         --dbms_output.put_line(v_procesar);   
         execute immediate (v_procesar) ;
    end loop;
  EXCEPTION
     WHEN OTHERS THEN
       RAISE_APPLICATION_ERROR(-20000,'ERROR EN PR_GEN_RUB_CONCILIACION: '||sqlerrm);
  END;
---FIN DE PR_GEN_RUB_CONCILIACION

--Proceso para insercion de movimientos del rubro
PROCEDURE PR_CON_CARGA
(v_cod_rubro varchar2,
v_consulta long,
v_fec_inicio varchar2 default null) IS
  v_fecha           varchar2(10);
  v_fec_proceso     varchar2(10);
  v_consulta2       long;
  
  BEGIN
    --null;
    v_fecha := null;
    v_fec_proceso := null;
    
    select to_char(sysdate,'dd/mm/yyyy') into v_fec_proceso from dual;        
                        
     ---busca la ultima fecha de proceso en cb_con_det y trae los movimientos con fecha mayor a esta
     select to_char(max(d.fecha),'dd/mm/yyyy') into v_fecha---fecha de los movimientos
     from 
     (select a.fecha from cb_con_rub_det a
     where a.cod_rubro=v_cod_rubro
     union all
     select b.fecha from cb_con_rub_det_his b
     where b.cod_rubro=v_cod_rubro) d;
           
     IF v_fecha is null then
        if v_fec_inicio is not null then
           v_fecha:=v_fec_inicio;
        else
          select to_char(min(d.fecha),'dd/mm/yyyy') into v_fecha from  
          cb_asi_automaticos_det d
          where d.cod_rubro=v_cod_rubro;
                
          IF v_fecha is null then
            v_fecha:='01/01/1900';
          end if;
        end if;           
     end if; 
      
     --inserta las partidas a conciliar
     v_consulta2 := replace(v_consulta,'[p_fecha]',' to_date("' ||v_fecha|| '","DD/MM/YYYY")');
     v_consulta2 := replace(v_consulta2,'[p_fec_proceso]',' to_date("' ||v_fec_proceso|| '","DD/MM/YYYY")');
     v_consulta2 := replace(v_consulta2,'"','''');
      
     --dbms_output.put_line(v_consulta2);   
     execute immediate v_consulta2;
     
     update CB_CON_RUB_DET t set hora = '23:59:59', cotizacion=999999 where t.hora = '24:00:00';
     
     update cb_con_rub_det
          set mov_cuadre = null
        where mov_cuadre is not null
          and mov_cuadre not in (9999999997,9999999998,9999999999)
          and cod_rubro = v_cod_rubro;
       
  EXCEPTION
     WHEN OTHERS THEN
       RAISE_APPLICATION_ERROR(-20000,'ERROR EN PR_CON_CARGA: '||sqlerrm);
  END;
--- fin del PR_CON_CARGA------------------------------------


--Proceso de conciliacion por monto, cod_moneda, nro_documento
PROCEDURE PR_CON_MTO_MON_DOC
(v_cod_rubro varchar2,
v_mov_inicial varchar2,
v_mov_final varchar2)
 is
   v_fecha           date;
   v_hora            cb_con_rub_det.hora%type;
   v_cod_usuario     cb_con_rub_det.cod_usuario%type;
   v_nro_secuencia   cb_con_rub_det.nro_secuencia%type;
   -- v_cuadre          number(10);
 ---cursor
 cursor c_cuadre_doc is
       select * from cb_con_rub_det x
       where x.tip_mov=v_mov_inicial 
       and exists(select 1 from cb_con_rub_det c
       where c.monto=x.monto
       and c.cod_moneda=x.cod_moneda
       and c.nro_documento=x.nro_documento
       and c.mov_cuadre is null
       and c.cod_rubro=v_cod_rubro)
       and x.mov_cuadre is null
       and x.cod_rubro=v_cod_rubro
       for update of mov_cuadre
       order by fecha;

BEGIN
     --- Cuadro directo 
     for i in c_cuadre_doc loop
      --- Buscar movimiento del débito o crédito que le corresponda
      Begin
         select fecha, hora, cod_usuario, nro_secuencia
           into v_fecha, v_hora, v_cod_usuario, v_nro_secuencia
           from cb_con_rub_det x
          where tip_mov=v_mov_final
            and monto= i.monto
            and cod_moneda=i.cod_moneda
            and x.cod_ofi_origen = i.cod_oficina
            and mov_cuadre is null
            and rownum=1
            and x.cod_rubro=v_cod_rubro
            and x.nro_documento=i.nro_documento;
            
      --- Si existe movimiento, actualizar mov_cuadre del débito o crédito
      update cb_con_rub_det
         set mov_cuadre = v_cuadre
       where fecha = v_fecha
         and hora = v_hora
         and cod_usuario = v_cod_usuario
         and nro_secuencia = v_nro_secuencia
         and monto = i.monto
         and cod_moneda = i.cod_moneda
         and cod_ofi_origen = i.cod_oficina
         and nro_documento=i.nro_documento
         and tip_mov=v_mov_final
         and rownum=1
         and cod_rubro=v_cod_rubro
         and mov_cuadre is null;
         
      --- Actualizar mov_cuadre
      update cb_con_rub_det
         set mov_cuadre = v_cuadre
       where current of c_cuadre_doc;
      v_cuadre := v_cuadre + 1;
        
      exception
         when no_data_found then null;
         when too_many_rows then null;
      end;
      end loop;
EXCEPTION
    WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(-20000,'ERROR EN PR_CON_MTO_MON_DOC: '||sqlerrm);
END;
---------------------------------------------------------------------------------------------------------------------
-- fin de PR_CON_MTO_MON_DOC

--Proceso de conciliacion por monto, cod_moneda, nro_cuenta
PROCEDURE PR_CON_MTO_MON_CUENTA
(v_cod_rubro varchar2,
v_mov_inicial varchar2,
v_mov_final varchar2)
 is
   v_fecha           date;
   v_hora            cb_con_rub_det.hora%type;
   v_cod_usuario     cb_con_rub_det.cod_usuario%type;
   v_nro_secuencia   cb_con_rub_det.nro_secuencia%type;

  ---cursor
  cursor c_cuadre_por_cta is
       select * from cb_con_rub_det x
       where x.tip_mov=v_mov_inicial 
       and exists(select 1 from cb_con_rub_det c
       where c.monto=x.monto
       and c.cod_moneda=x.cod_moneda
       and c.nro_cuenta=x.nro_cuenta
       and c.mov_cuadre is null
       and c.cod_rubro=v_cod_rubro)
       and x.mov_cuadre is null
       and x.cod_rubro=v_cod_rubro
       for update of mov_cuadre
       order by fecha;
       
BEGIN
    for j in c_cuadre_por_cta loop
    begin
      --- Buscar movimiento que le corresponda
         select fecha, hora, cod_usuario, nro_secuencia
           into v_fecha, v_hora, v_cod_usuario, v_nro_secuencia
           from cb_con_rub_det x
          where tip_mov=v_mov_final
            and monto= j.monto
            and cod_moneda=j.cod_moneda
            and mov_cuadre is null
            and x.nro_cuenta=j.nro_cuenta
            and x.cod_rubro=v_cod_rubro
                and to_date(to_char(x.fecha,'ddmmyyyy')||' '||x.hora, 'ddmmyyyy hh24:mi:ss') =
                (select min(to_date(to_char(fecha,'ddmmyyyy')||' '||hora, 'ddmmyyyy hh24:mi:ss'))
                   from cb_con_rub_det y
                  where y.tip_mov=x.tip_mov
                    and y.monto=x.monto
                    and y.cod_moneda=x.cod_moneda
                    and y.nro_cuenta=x.nro_cuenta
                    and y.mov_cuadre is null
                    and y.fecha >= j.fecha
                    and y.cod_rubro=v_cod_rubro);
      --- Si existe movimiento, actualizar mov_cuadre 
      update cb_con_rub_det
         set mov_cuadre = v_cuadre
       where fecha = v_fecha
         and hora = v_hora
         and cod_usuario = v_cod_usuario
         and nro_secuencia = v_nro_secuencia
         and monto = j.monto
         and cod_moneda = j.cod_moneda
         and nro_cuenta=j.nro_cuenta
         and tip_mov=v_mov_final
         and rownum=1
         and cod_rubro=v_cod_rubro
         and mov_cuadre is null;
      --- Actualizar mov_cuadre del crédito
      update cb_con_rub_det
         set mov_cuadre = v_cuadre
       where current of c_cuadre_por_cta;
      v_cuadre := v_cuadre + 1;
      exception
         when no_data_found then null;
         when too_many_rows then null;
      end;
      end loop;
EXCEPTION
    WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(-20000,'ERROR EN PR_CON_MTO_MON_CUENTA: '||sqlerrm);
END;
---------------------------------------------------------------------------------------------------------------------
-- fin de PR_CON_MTO_MON_CUENTA

--Proceso de conciliacion agrupando por creditos o débitos según el parámetro dado
PROCEDURE PR_CON_TIPOMOV
(v_cod_rubro varchar2,
v_mov_inicial varchar2,
v_mov_final varchar2)
 is
   v_fecha           date;
   v_hora            cb_con_rub_det.hora%type;
   v_cod_usuario     cb_con_rub_det.cod_usuario%type;
   v_nro_secuencia   cb_con_rub_det.nro_secuencia%type;

  ---cursor
  cursor c_cuadre_tot is
       select t.nro_cuenta, t.nro_documento4, t.cod_moneda, sum(t.monto) monto, max(t.fecha) fecha
       from cb_con_rub_det t
       where t.mov_cuadre is null
       and t.tip_mov=v_mov_inicial
       and t.cod_rubro=v_cod_rubro
       group by t.nro_cuenta, t.nro_documento4, t.cod_moneda;
       
BEGIN
    for k in c_cuadre_tot loop
   begin
      --- Buscar movimiento de dèbito que le corresponda
         select fecha, hora, cod_usuario, nro_secuencia
           into v_fecha, v_hora, v_cod_usuario, v_nro_secuencia
           from cb_con_rub_det x
          where tip_mov=v_mov_final
            and monto= k.monto
            and cod_moneda=k.cod_moneda
            and mov_cuadre is null
            and cod_rubro=v_cod_rubro
            and nro_cuenta=k.nro_cuenta;
      --- Si existe movimiento, actualizar mov_cuadre del dèbito
      update cb_con_rub_det
         set mov_cuadre = v_cuadre
       where fecha = v_fecha
         and hora = v_hora
         and cod_usuario = v_cod_usuario
         and nro_secuencia = v_nro_secuencia
         and monto = k.monto
         and cod_moneda = k.cod_moneda
         and nro_cuenta=k.nro_cuenta
         and tip_mov=v_mov_final
         and rownum=1
         and cod_rubro=v_cod_rubro
         and mov_cuadre is null;
      --- Actualizar mov_cuadre del crédito
      update cb_con_rub_det
         set mov_cuadre = v_cuadre
       where nro_cuenta = k.nro_cuenta
         and cod_moneda= k.cod_moneda
         and tip_mov=v_mov_inicial
         and cod_rubro=v_cod_rubro
         and mov_cuadre is null
         and nro_documento4 = k.nro_documento4;
      v_cuadre := v_cuadre + 1;
      exception
         when no_data_found then null;
         when too_many_rows then null;
      end;
      end loop;
EXCEPTION
    WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(-20000,'ERROR EN PR_CON_TIPOMOV: '||sqlerrm);
END;
---------------------------------------------------------------------------------------------------------------------
-- fin de PR_CON_TIPOMOV

--Proceso de pase a historico de conciliados
PROCEDURE PR_CON_PAS_HIS
(v_cod_rubro varchar2) is
BEGIN
   update CB_CON_RUB_DET t set hora = '24:00:00', cotizacion=NULL where t.hora = '23:59:59' and cotizacion=999999;
   --inserta en el historico las partidas conciliadas
   insert into cb_con_rub_det_his(fecha,hora,cod_usuario,nro_secuencia,cod_rubro,fec_conciliacion,mov_cuadre,con_forma) 
   select fecha,hora,cod_usuario,nro_secuencia,cod_rubro,trunc(sysdate),mov_cuadre,'automatico' from cb_con_rub_det t
   where t.mov_cuadre is not null and t.cod_rubro=v_cod_rubro;
   --elimina la spartidas conciliadas de cb_con_rub_det, dejando solo las pendientes
   execute immediate 'delete cb_con_rub_det where mov_cuadre is not null and cod_rubro=''' || v_cod_rubro || '''';
EXCEPTION
    WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(-20000,'ERROR EN PR_CON_PAS_HIS: '||sqlerrm);
END;
---------------------------------------------------------------------------------------------------------------------
-- fin de PR_CON_PAS_HIS

--Proceso de conciliacion por total de documento y cuenta
PROCEDURE PR_CON_TOT_DOC_CTA
(v_cod_rubro varchar2,
v_mov_inicial varchar2,
v_mov_final varchar2)
 is
  v_tot_monto       cb_con_rub_det.monto%type;
  ---cursor
  cursor c_cuadre_tot is
    select * from cb_con_rub_det x
    where x.tip_mov=v_mov_inicial 
    and x.mov_cuadre is null
    and x.cod_rubro=v_cod_rubro
    for update of mov_cuadre
    order by fecha;
       
BEGIN
   for reg in c_cuadre_tot loop
     begin
        --- Buscar movimiento de dèbito que le corresponda
         select nvl(sum(x.monto),0)
           into v_tot_monto
           from cb_con_rub_det x
          where tip_mov=v_mov_final
            and cod_moneda=reg.cod_moneda
            and mov_cuadre is null
            and x.nro_documento=reg.nro_documento
            and x.nro_cuenta=reg.nro_cuenta
            and x.cod_rubro=v_cod_rubro;
        --- Si existe movimiento, actualizar mov_cuadre del dèbito
        if v_tot_monto = reg.monto then
          update cb_con_rub_det
             set mov_cuadre = v_cuadre
           where cod_moneda = reg.cod_moneda
             and nro_cuenta=reg.nro_cuenta
             and nro_documento=reg.nro_documento
             and tip_mov=v_mov_final
             and cod_rubro=v_cod_rubro
             and mov_cuadre is null;
          --- Actualizar mov_cuadre del crédito
          update cb_con_rub_det
             set mov_cuadre = v_cuadre
           where current of c_cuadre_tot;
          v_cuadre := v_cuadre + 1;
        end if;
        exception
           when no_data_found then null;
           when too_many_rows then null;
        end;
      end loop;
EXCEPTION
    WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(-20000,'ERROR EN PR_CON_TOT_DOC_CTA: '||sqlerrm);
END;
---------------------------------------------------------------------------------------------------------------------
-- fin de PR_CON_TOT_DOC_CTA

--Proceso de conciliacion por total de montos de una fecha dada contra total de montos de otra fecha
PROCEDURE PR_CON_TOT_FEC_MON
(v_cod_rubro varchar2,
v_mov_inicial varchar2,
v_mov_final varchar2,
v_dias number)
 is
  v_tot_monto       cb_con_rub_det.monto%type;
  v_fecha           date;
  v_cod_moneda      cb_con_rub_det.cod_moneda%type;
  
  ---cursor
cursor c_cua_deb is
   select t.fecha, t.cod_moneda, sum(t.monto) monto
   from cb_con_rub_det t
   where t.mov_cuadre is null
   and t.cod_rubro=v_cod_rubro
   and t.tip_mov=v_mov_inicial
   group by t.fecha, t.cod_moneda
   order by t.fecha;

 --- Cuadro directo por total monto 
   BEGIN
   for reg in c_cua_deb loop
 
     --- Buscar movimiento de credito que le corresponda
      begin
         select c.fecha, c.cod_moneda, c.monto 
         into v_fecha, v_cod_moneda, v_tot_monto
         from (select x.fecha, x.cod_moneda,x.cod_rubro,sum(x.monto) monto
           from cb_con_rub_det x
           where tip_mov=v_mov_final            
           and mov_cuadre is null
           and x.cod_rubro=v_cod_rubro
           group by x.fecha, x.cod_moneda,x.cod_rubro)c
         where c.monto = reg.monto
         and c.fecha= pag_cal.fu_obt_fec_habil(reg.fecha+v_dias,1,7);
         
      --- Si existe movimiento, actualizar mov_cuadre del credito
      update cb_con_rub_det
         set mov_cuadre = v_cuadre
       where v_fecha = fecha         
         and cod_moneda = reg.cod_moneda         
         and tip_mov=v_mov_final         
         and mov_cuadre is null
         and cod_rubro=v_cod_rubro;
      --- Actualizar mov_cuadre del debito
      update cb_con_rub_det
         set mov_cuadre = v_cuadre
       where reg.fecha = fecha
         and cod_moneda= reg.cod_moneda
         and tip_mov=v_mov_inicial
         and mov_cuadre is null
         and cod_rubro=v_cod_rubro;
      v_cuadre := v_cuadre + 1;
      exception
         when no_data_found then null;
         when too_many_rows then null;
      end;
   end loop;
EXCEPTION
    WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(-20000,'ERROR EN PR_CON_TOT_FEC_MON: '||sqlerrm);
END; 
---fin PR_CON_TOT_FEC_MON

---Proceso de conciliacion por montos iguales
PROCEDURE PR_CON_TOT_MON
(v_cod_rubro varchar2,
v_mov_inicial varchar2,
v_mov_final varchar2
)
 is
  v_monto       cb_con_rub_det.monto%type;
    
---cursor
cursor c_cua_monto is
   select t.monto
   from cb_con_rub_det t
   where t.mov_cuadre is null
   and t.tip_mov=v_mov_inicial
   and t.cod_rubro=v_cod_rubro;
   
   --- Cuadro directo por monto 
   BEGIN
   for reg in c_cua_monto loop
      --- Buscar movimiento de credito que le corresponda
      begin
         select x.monto
           into v_monto
           from cb_con_rub_det x
          where tip_mov=v_mov_final
            and monto= reg.monto
            and mov_cuadre is null
            and cod_rubro=v_cod_rubro
            and rownum=1;
               
      --- Si existe movimiento, actualizar mov_cuadre del credito
      update cb_con_rub_det
         set mov_cuadre = v_cuadre
       where monto = reg.monto
         and tip_mov=v_mov_final
         and rownum=1
         and cod_rubro=v_cod_rubro
         and mov_cuadre is null;
      --- Actualizar mov_cuadre del debito
      update cb_con_rub_det
         set mov_cuadre = v_cuadre
       where monto=reg.monto
         and tip_mov=v_mov_inicial
         and rownum=1
         and cod_rubro=v_cod_rubro
         and mov_cuadre is null;
      v_cuadre := v_cuadre + 1;
      exception
         when no_data_found then null;
         when too_many_rows then null;
      end;
   end loop;
EXCEPTION
    WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(-20000,'ERROR EN PR_CON_TOT_MON: '||sqlerrm);
END;
--Fin Proceso de conciliacion por montos iguales   

end PAB_CON;
/

