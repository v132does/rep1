create or replace function it.fug_cal_fec_habil(p_fecha in date,p_can_dias in number) return date is

v_fecha    date        := p_fecha;
v_can_dias number(8)   := p_can_dias;
v_dia      varchar2(8);
v_habil    boolean;
v_cantidad number(5)   :=0;
e_error    exception;
begin
     if p_can_dias<0 then
         raise e_error;
     end if;
     
     if p_can_dias=0 then
        return p_fecha;
     end if;
     
     loop
             v_habil   :=true;
             v_cantidad:=0;
             v_fecha   :=v_fecha+1;

             select to_char(trunc(v_fecha),'DY','NLS_DATE_LANGUAGE = ENGLISH')
             into v_dia
             from dual;

             if trim(v_dia) in ('SAT','SUN') THEN
                 v_habil:=false;
             end if;

             if v_habil then --se verifica si es feriado

               select count(*)
               into v_cantidad
               from it.ba_feriados fe
               where fe.fecha=v_fecha;

               if v_cantidad>0 then
                  v_habil:=false;
               end if;
             end if;

             if v_habil then
                v_can_dias:=v_can_dias-1;
             end if;

             exit when v_can_dias=0;
     end loop;
     return v_fecha;
exception
    when e_error then
       raise_application_error(-20001,'La cantidad de dias debe ser un valor +');
    when others then
       raise_application_error(-20000,'Error en el calculo de la fecha '||sqlerrm);
end;
/

