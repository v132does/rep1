CREATE OR REPLACE PROCEDURE IT.prb_gen_pos_cambio is

v_cont number := 0;
v_cont_ofi number := 0;
v_fec_actual date;
v_ofi_desc varchar2(100) := '';
v_tot_ofi number :=0;
v_tot_me number :=0;
v_last_ofi number := 0;
v_cal_saldo number :=0;
---cursor
 cursor c_pos is
       select i.cod_divisa, i.ofi_descripcion,i.cod_oficina, i.cod_moneda,
       sum(i.total_activo) total_activo,
       sum(i.total_pasivo) total_pasivo,
       sum(i.saldo_deudor) saldo_deudor,
       sum(i.saldo_acreedor) saldo_acreedor,
       sum(i.cv_guaranies) cv_guaranies,
       sum(i.posicion_me) posicion_me,
       sum(i.posicion_gs) posicion_gs
       from bv_pos_cambio i
       group by i.cod_divisa,i.ofi_descripcion,i.cod_oficina, i.cod_moneda
       order by i.cod_oficina, i.cod_divisa;
  
 cursor c_con is     
      select t.cod_divisa, t.cod_moneda ,
      sum(t.total_activo) total_activo,
      sum(t.total_pasivo) total_pasivo,
      --sum(t.saldo_deudor) saldo_deudor,
      --sum(t.saldo_acreedor) saldo_acreedor,
      case when sum(nvl(t.saldo_deudor,0) + nvl(t.saldo_acreedor,0)) < 0 then
            0
       else
            sum(nvl(t.saldo_deudor,0) + nvl(t.saldo_acreedor,0))
       end saldo_deudor,
       case when sum(nvl(t.saldo_deudor,0) + nvl(t.saldo_acreedor,0)) > 0 then
            0
       else
            sum(nvl(t.saldo_deudor,0) + nvl(t.saldo_acreedor,0))
       end saldo_acreedor,
      sum(t.cv_guaranies) cv_guaranies,
      sum(t.posicion_me) posicion_me,
      sum(t.posicion_gs) posicion_gs
      from bv_pos_cambio t
      group by t.cod_divisa, t.cod_moneda;

begin

    -- inicializa variables
    v_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(1);
    execute immediate('delete from TMP_POS_CAMBIO');

    -- carga linea 1
     insert into TMP_POS_CAMBIO (NRO_BLOQUE, NRO_LINEA, FECHA, TEXTO) values(
     -2, v_cont, v_fec_actual, rpad(1,6,CHR(32))||rpad('BBVA Banco',22,CHR(32))||'CUADRO DE SALDOS DE MONEDAS EXTRANJERAS AL'||CHR(32) || v_fec_actual);
     v_cont := v_cont + 1;

     -- carga linea 2
    insert into TMP_POS_CAMBIO (NRO_BLOQUE, NRO_LINEA, FECHA, TEXTO) values(
    -1, v_cont, v_fec_actual, rpad('0',98,CHR(32))||'POSICION DE CAMBIOS');
    v_cont := v_cont + 1;

    -- carga linea 3
    insert into TMP_POS_CAMBIO (NRO_BLOQUE, NRO_LINEA, FECHA, TEXTO) values(
    0, v_cont, v_fec_actual,
        rpad(' MONEDAS',9,CHR(32))
      ||lpad('TOTAL ACTIVO',19,CHR(32))
      ||lpad('TOTAL PASIVO',19,CHR(32))
      ||lpad('SALDO DEUDOR',19,CHR(32))
      ||lpad('SALDO ACREEDOR',19,CHR(32))
      ||lpad('CV/ GUARANIES',19,CHR(32))
      ||lpad('SALDO M/E',19,CHR(32))
      ||lpad('CV/ GUARANIES',19,CHR(32)));
     v_cont := v_cont + 1;
     
    -- carga cuerpo
    for i in c_pos loop
        if v_ofi_desc = i.ofi_descripcion then
           v_cont := v_cont + 1;
        else
            -- linea divisoria y totalizado
            if v_cont_ofi > 0 then
                insert into TMP_POS_CAMBIO (NRO_BLOQUE, NRO_LINEA, FECHA, TEXTO) values(
                i.cod_oficina, v_cont, v_fec_actual,''
                || rpad('-',85,CHR(45)) 
                || replace(replace(replace(to_char(decode(v_tot_ofi,0,0,to_char(v_tot_ofi)),'999,999,999,999.99'),'.','|'),',','.'),'|',',') || ' '
                || lpad('-',18,CHR(45)) 
                || replace(replace(replace(to_char(decode(v_tot_me,0,0,to_char(v_tot_me )),'999,999,999,999.99'),'.','|'),',','.'),'|',',')
                );
                
                insert into TMP_POS_CAMBIO (NRO_BLOQUE, NRO_LINEA, FECHA, TEXTO) values(
                i.cod_oficina, v_cont, v_fec_actual,''
                || rpad('-',85,CHR(45)) 
                || replace(replace(replace(to_char(decode(v_tot_ofi,0,0,to_char(v_tot_ofi)),'999,999,999,999.99'),'.','|'),',','.'),'|',',') || ' '
                || lpad('-',18,CHR(45)) 
                || replace(replace(replace(to_char(decode(v_tot_me,0,0,to_char(v_tot_me )),'999,999,999,999.99'),'.','|'),',','.'),'|',',')
                );
                v_cont := v_cont + 1;
                v_tot_ofi := 0;
                v_tot_me := 0;          
            end if;
            
            v_ofi_desc:=i.ofi_descripcion;
             -- carga linea 3
            insert into TMP_POS_CAMBIO (NRO_BLOQUE, NRO_LINEA, FECHA, TEXTO) values(
            i.cod_oficina, v_cont, v_fec_actual,' OFIC.'|| v_ofi_desc);
            v_cont_ofi:=v_cont_ofi+1;
            v_cont := v_cont + 1;
        end if;
    
    -- carga linea 3
    insert into TMP_POS_CAMBIO (NRO_BLOQUE, NRO_LINEA, FECHA, TEXTO) values(
    i.cod_oficina, v_cont, v_fec_actual,rpad(' '||i.cod_moneda,9,CHR(32))
      ||replace(replace(replace(to_char(decode(nvl(i.total_activo,0),0,0,to_char(i.total_activo*-1)),'999,999,999,999.99'),'.','|'),',','.'),'|',',')--se invierte el signo para que sea igual a la AS
      ||replace(replace(replace(to_char(decode(nvl(i.total_pasivo,0),0,0,to_char(i.total_pasivo*-1)),'999,999,999,999.99'),'.','|'),',','.'),'|',',')--se invierte el signo para que sea igual a la AS
      ||replace(replace(replace(to_char(decode(nvl(i.saldo_deudor,0),0,0,to_char(i.saldo_deudor*-1)),'999,999,999,999.99'),'.','|'),',','.'),'|',',')
      ||replace(replace(replace(to_char(decode(nvl(i.saldo_acreedor,0),0,0,to_char(i.saldo_acreedor*-1)),'999,999,999,999.99'),'.','|'),',','.'),'|',',')
      ||replace(replace(replace(to_char(decode(nvl(i.cv_guaranies,0),0,0,to_char(i.cv_guaranies*-1)),'999,999,999,999.99'),'.','|'),',','.'),'|',',')
      ||replace(replace(replace(to_char(decode(nvl(i.posicion_me,0),0,0,to_char(i.posicion_me)),'999,999,999,999.99'),'.','|'),',','.'),'|',',')
      ||replace(replace(replace(to_char(decode(nvl(i.posicion_gs,0),0,0,i.posicion_gs),'999,999,999,999.99'),'.','|'),',','.'),'|',','));
      
    -- calcula diferencia de la moneda
    if i.cod_oficina = 31 then
       v_cal_saldo := 0;
       if nvl(i.saldo_deudor,0) <> 0 then
          v_cal_saldo := (i.saldo_deudor *-1) - i.posicion_me;--se resta con la posicion
       end if;
       if nvl(i.saldo_acreedor,0) <> 0 then
          v_cal_saldo := (i.saldo_acreedor*-1) - i.posicion_me;--se resta con la posicion
       end if;
       if v_cal_saldo <> 0 then
         v_cont := v_cont + 1;
         insert into TMP_POS_CAMBIO (NRO_BLOQUE, NRO_LINEA, FECHA, TEXTO) values(
          i.cod_oficina, v_cont, v_fec_actual,''
          || rpad('*************',47,CHR(32)) 
          || replace(replace(replace(to_char(to_char(v_cal_saldo),'999,999,999,999.99'),'.','|'),',','.'),'|',',')
          );
                
            
       end if;
    end if;
    
    v_tot_ofi := v_tot_ofi + nvl(i.cv_guaranies,0);
    v_tot_me := v_tot_me + nvl(i.posicion_gs,0);
    v_last_ofi := i.cod_oficina;
    
   end loop;
   
   -- linea divisoria y totalizado final oficinas
    if v_cont_ofi > 0 then
        v_last_ofi:=v_last_ofi+1;
        insert into TMP_POS_CAMBIO (NRO_BLOQUE, NRO_LINEA, FECHA, TEXTO) values(
        v_last_ofi, 1, v_fec_actual,''
        || rpad('-',85,CHR(45)) 
        || replace(replace(replace(to_char(decode(v_tot_ofi,0,'+0',to_char(v_tot_ofi)),'999,999,999,999.99'),'.','|'),',','.'),'|',',') || ' '
        || lpad('-',18,CHR(45)) 
        || replace(replace(replace(to_char(decode(v_tot_me,0,'+0',to_char(v_tot_me )),'999,999,999,999.99'),'.','|'),',','.'),'|',',')
       );
        
        insert into TMP_POS_CAMBIO (NRO_BLOQUE, NRO_LINEA, FECHA, TEXTO) values(
        v_last_ofi, 1, v_fec_actual,''
        || rpad('-',85,CHR(45)) 
        || replace(replace(replace(to_char(decode(v_tot_ofi,0,'+0',to_char(v_tot_ofi)),'999,999,999,999.99'),'.','|'),',','.'),'|',',') || ' '
        || lpad('-',18,CHR(45)) 
        || replace(replace(replace(to_char(decode(v_tot_me,0,'+0',to_char(v_tot_me )),'999,999,999,999.99'),'.','|'),',','.'),'|',',')
       );
       
        --v_cont := v_cont + 1;
        --v_tot_ofi := 0;
        --v_tot_me := 0;          
    end if;
    
    
    -- consolidado
    v_last_ofi:=v_last_ofi+1;    
    insert into TMP_POS_CAMBIO (NRO_BLOQUE, NRO_LINEA, FECHA, TEXTO) values(
    v_last_ofi, 0, v_fec_actual,' CONSOLIDADA');
   
    v_last_ofi := v_last_ofi+1; 
  
    v_tot_ofi := 0;
    v_tot_me := 0;
    v_cont := 0;
    for j in c_con loop 
      
      insert into TMP_POS_CAMBIO (NRO_BLOQUE, NRO_LINEA, FECHA, TEXTO) values(
      v_last_ofi, v_cont, v_fec_actual,rpad(' '||j.cod_moneda,9,CHR(32))
        ||replace(replace(replace(to_char(decode(nvl(j.total_activo,0),0,'+0',to_char(j.total_activo*-1)),'999,999,999,999.99'),'.','|'),',','.'),'|',',')--se invierte el signo para que sea igual a la AS
        ||replace(replace(replace(to_char(decode(nvl(j.total_pasivo,0),0,'+0',to_char(j.total_pasivo*-1)),'999,999,999,999.99'),'.','|'),',','.'),'|',',')--se invierte el signo para que sea igual a la AS
        ||replace(replace(replace(to_char(decode(nvl((j.saldo_deudor),0),0,'+0',to_char((j.saldo_deudor)*-1)),'999,999,999,999.99'),'.','|'),',','.'),'|',',')
        ||replace(replace(replace(to_char(decode(nvl((j.saldo_acreedor),0),0,'+0',to_char((j.saldo_acreedor)*-1)),'999,999,999,999.99'),'.','|'),',','.'),'|',',')
        ||replace(replace(replace(to_char(decode(nvl(j.cv_guaranies,0),0,'+0',to_char(j.cv_guaranies*-1)),'999,999,999,999.99'),'.','|'),',','.'),'|',',')
        ||replace(replace(replace(to_char(decode(nvl(j.posicion_me,0),0,'+0',to_char(j.posicion_me)),'999,999,999,999.99'),'.','|'),',','.'),'|',',')
        ||replace(replace(replace(to_char(decode(nvl(j.posicion_gs,0),0,'+0',j.posicion_gs),'999,999,999,999.99'),'.','|'),',','.'),'|',',')
        );
      
      -- calcula diferencia de la moneda    
      v_cal_saldo := 0;
      if nvl(j.saldo_deudor,0) <> 0 then
          v_cal_saldo := (j.saldo_deudor*-1) - j.posicion_me;
      end if;
      if nvl(j.saldo_acreedor,0) <> 0 then
          v_cal_saldo := (j.saldo_acreedor*-1) - j.posicion_me;
      end if;
      if v_cal_saldo <> 0 then
         v_cont := v_cont + 1;
         insert into TMP_POS_CAMBIO (NRO_BLOQUE, NRO_LINEA, FECHA, TEXTO) values(
          v_last_ofi, v_cont, v_fec_actual,''
          || rpad('*************',42,CHR(32)) 
          || replace(replace(replace(to_char(to_char(v_cal_saldo),'999,999,999,999.99'),'.','|'),',','.'),'|',',')
          );           
      end if;
    
      v_cont := v_cont + 1;
      v_tot_ofi := v_tot_ofi + nvl(j.cv_guaranies,0);
      v_tot_me := v_tot_me + nvl(j.posicion_gs,0);
    
    end loop;
        v_last_ofi:=v_last_ofi+1;
        
        insert into TMP_POS_CAMBIO (NRO_BLOQUE, NRO_LINEA, FECHA, TEXTO) values(
        v_last_ofi, 1, v_fec_actual,''
        || rpad('-',85,CHR(45)) 
        || replace(replace(replace(to_char(decode(v_tot_ofi,0,'+0',to_char(v_tot_ofi)),'999,999,999,999.99'),'.','|'),',','.'),'|',',') || ' '
        || lpad('-',18,CHR(45)) 
        || replace(replace(replace(to_char(decode(v_tot_me,0,'+0',to_char(v_tot_me )),'999,999,999,999.99'),'.','|'),',','.'),'|',',')
        );
        insert into TMP_POS_CAMBIO (NRO_BLOQUE, NRO_LINEA, FECHA, TEXTO) values(
        v_last_ofi, 1, v_fec_actual,''
        || rpad('-',85,CHR(45)) 
        || replace(replace(replace(to_char(decode(v_tot_ofi,0,'+0',to_char(v_tot_ofi)),'999,999,999,999.99'),'.','|'),',','.'),'|',',') || ' '
        || lpad('-',18,CHR(45)) 
        || replace(replace(replace(to_char(decode(v_tot_me,0,'+0',to_char(v_tot_me )),'999,999,999,999.99'),'.','|'),',','.'),'|',',')
        );
        
    --Aqui incluir la generacion de archivo o envio por email
    -- para imprimir el informe
    -- select * from TMP_POS_CAMBIO t order by t.NRO_BLOQUE asc, t.NRO_LINEA asc;
    
end;
/

