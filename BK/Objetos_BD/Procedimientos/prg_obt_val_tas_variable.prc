CREATE OR REPLACE PROCEDURE IT.PRG_OBT_VAL_TAS_VARIABLE
 (P_NRO_SOLICITUD IN NUMBER default null  --Nro de Solicitud
 ,P_FECHA IN DATE  --Fecha de Renegociacion
 ,P_TIPO IN VARCHAR2 --'S'pread/'T'asa de Referencia/'F' Tasa Final
 ,p_cod_periodo in varchar2 default null --Codigo de Periodo de la tasa variable
 ,p_cod_moneda in varchar2 default null --Codigo de moneda de la sata variable
 ,p_val_ingresado in number default null --Codigo de moneda de la sata variable
 ,p_cod_tasa out varchar2 --codigo de Tasa
 ,p_val_devuelto out number  --Valor de la tasa
 )
/****** Procedimiento creado para retornar valor de Tasa Variable  ********
--->  Para la Re-negociación 1
Tasa de Referencia : Seria la tasa que tenemos en la pizarra de Tasa Variable
(LRM 360/LIBOR 360).
Spread:
  -> Si el tipo de Spread es TEMPORAL: Se utiliza el Spread inicial (De la solicitud inicial) .
  -> Si el tipo de Spread es DEFINITIVO:  Se utiliza el último Spread Cargado.
  (para la Renenegociacion 1, el spread Temporal y el Definitivo siempre seran los mismos
  ((De la solicitud inicial))) .
Tasa de Interés : Suma de Tasa de Referencia + Spread (O lo que se ingresó como Tasa Aplicada
     en forma manual).
---> Para la Re-negociación 2,3,4....Final
Tasa de Referencia : Seria la tasa que tenemos en la pizarra de Tasa Variable
(LRM 360/LIBOR 360).
Spread:
   -> Si el tipo de Spread es TEMPORAL: Se utiliza el Spread inicial.(De la solicitud inicial) . Si
   -> Si el tipo de Spread es DEFINITIVO:  Se utiliza el último Spread Cargado.
      (Para la renegociacion 2 seria el spread asignado para la renegociacion 1)
Tasa de Interés : Suma de Tasa de Referencia + Spread
      (O lo que se ingresó como Tasa Aplicada en forma manual)
*/
IS

v_fec_actual date:= pag_cal.FU_OBT_FEC_ACTUAL(6);
v_fecha date;

--SPREAD
V_COD_MONEDA PR_TAS_VARIABLES.COD_MONEDA%TYPE;
V_COD_PERIODO PR_TAS_VARIABLES.COD_PERIODO%TYPE;
V_FEC_PRI_RENEGOCIACION DATE;
V_SPR_INI PR_TAS_VARIABLES.SPREAD%TYPE;
V_TAS_REF_INI PR_TAS_VARIABLES.TAS_INTERES%TYPE;
V_TAS_APLI_INI PR_TAS_VARIABLES.TAS_REFERENCIA%TYPE;
V_TIP_SPREAD PR_TAS_VARIABLES.TIP_SPREAD%TYPE;
V_VALOR  PR_TAS_VARIABLES.SPREAD%TYPE;
v_can_renegociado number(10):=0;
v_respuesta number(18,4);
v_devuelto number(18,4);
v_spread number(18,4);
v_tas_referencia number(18,4);
v_cod_tas_variable VARCHAR2(20);
v_personalizada varchar2(1):=null;



PROCEDURE LP_OBT_VAL_TAS_REFERENCIA(p_cod_moneda IN varchar2,
      p_cod_periodo IN VARCHAR2,
      p_fecha in date,
      p_resultado out number) is
v_fec_ult date;
v_resultado number(18,4);
begin
     --Obtenemos la maxima Fecha cargada, es la última
    begin
      select max(a.fecha)
         into v_fec_ult
          from pr_tas_referencias a
           where a.cod_periodo= v_cod_periodo
             and a.cod_moneda= v_cod_moneda;
    exception
      when no_data_found then
        v_fec_ult := null;
    end;

    if v_fec_ult is not null then
       begin
        select a.monto
           into v_resultado
            from pr_tas_referencias a
               where a.cod_periodo= v_cod_periodo
                 and a.cod_moneda= v_cod_moneda
                 and a.fecha= v_fec_ult ;
       exception
         when no_data_found then
            v_resultado := null;
       end;
    else
       v_resultado:=0;
    end if;
    p_resultado:= v_resultado;
EXCEPTION
    WHEN OTHERS THEN
         raise_application_error(-20000,'Obt.Tas.Ref: '|| sqlerrm);
END;

PROCEDURE LP_OBT_VAL_SPREAD(p_nro_solicitud in number,
      p_tipo IN varchar2,  --'D'efinitivo/'T'emporal
      p_fecha in date,
      p_spread_ini in number,
      p_es_pri_reneg in varchar2, --Es primera Reneg (S/N)
      p_resultado out number) is
v_fec_ult date;
v_resultado number(18,4);
begin
if p_es_pri_reneg ='S' then
   --Si es la primera re-negociacion se toma siempre el spread inicial
   --de la solicitud por mas que sea de tipo (I-T-D)
    v_resultado:= p_spread_ini;
else
  --Corresponde a negociaciones 2,3,4...N
  IF P_TIPO='D' THEN
     --Si el tipo de Spread es DEFINITIVO:  Se utiliza el último Spread Cargado.
    --Obtenemos la maxima Fecha renegociada
    begin
      select max(a.fec_vencimiento)
         into v_fec_ult
          from pr_tas_variables_det a
           where a.nro_solicitud= p_nro_solicitud
              and a.fec_renegociacion is not null
              and a.spread is not null
              and a.nro_cuota > 1
              and a.renegociacion='S';
    exception
      when no_data_found then
        v_fec_ult := null;
    end;
    IF v_fec_ult IS NULL THEN
       --Entonces se utiliza el spread de la solicutd inicial
       v_resultado:= p_spread_ini;
    else
          --Traemos el ultimo Spread negociado
          begin
           select a.spread
            into v_resultado
               from pr_tas_variables_det a
                 where a.nro_solicitud= p_nro_solicitud
                 and a.fec_vencimiento=v_fec_ult;
          exception
            when no_data_found then
              v_resultado := 0;
          end;
    END IF;
  elsif P_TIPO='T' THEN
        --Si el tipo de Spread es TEMPORAL: Se utiliza el Spread inicial.
              --(De la solicitud inicial) .
         v_resultado:= p_spread_ini;

  elsif P_TIPO='I' THEN
        --Si el tipo de Spread es TEMPORAL: Se utiliza el Spread inicial.
              --(De la solicitud inicial) .
         v_resultado:= p_spread_ini;

  END IF;
end if;
    p_resultado:= v_resultado;
EXCEPTION
    WHEN OTHERS THEN
         raise_application_error(-20000,'Obt.Spread: '|| sqlerrm);
END;


PROCEDURE LP_OBT_TAS_INTERES_FINAL(p_nro_solicitud in number,
      p_fecha in date,
      p_spread in number,
      p_tas_ref in number,
      p_resultado out number,
      p_personalizada out varchar2) is
v_fec_ult_per date;
v_fec_ult_ren date;
v_resultado number(18,4);
v_tas_utilizada number(18,4); --Para verificar si se ajustó en forma manual
v_es_personalizada varchar2(1):= null;
v_tip_spread varchar2(1):='I';
v_val_tas_definitiva number(18,4);
begin
    --Obtenemos el valor de Tipo Spread
begin
      select NVL(a.tip_spread,'I')
         into v_tip_spread
          from pr_tas_variables a
           where a.nro_solicitud= p_nro_solicitud;
    exception
      when no_data_found then
           v_tip_spread:='I';
    end;





    --Obtenemos la maxima Fecha renegociada
    begin
      select max(a.fec_vencimiento)
         into v_fec_ult_ren
          from pr_tas_variables_det a
           where a.nro_solicitud= p_nro_solicitud
              and a.fec_renegociacion is not null
              and a.spread is not null
              and a.nro_cuota > 1
              and a.renegociacion='S';
    exception
      when no_data_found then
           v_fec_ult_ren := null;
    end;

    IF v_tip_spread ='D' and v_fec_ult_ren is not null then 
      
           begin
              select a.tas_utilizada
                 into v_val_tas_definitiva
                  from pr_tas_variables_det a
                   where a.nro_solicitud= p_nro_solicitud
                      and a.fec_vencimiento =v_fec_ult_ren
                      and a.spread is not null
                      and a.nro_cuota > 1
                      and a.renegociacion='S';
            exception
              when no_data_found then
                   v_val_tas_definitiva := 0;
            end;
    end if; 


    --if v_fec_ult_ren is null then

         --Buscamos sino personalizó
          begin
              select max(a.fec_vencimiento)
               into v_fec_ult_per
                 from pr_tas_variables_det a
                 where a.nro_solicitud= p_nro_solicitud
                  and a.fec_renegociacion is null
                  and a.spread is null
                  and a.nro_cuota > 1
                  and a.renegociacion='S'
                  and a.tas_utilizada is not null
                 ;
          exception
            when no_data_found then
              v_fec_ult_per := null;
          end;
   -- end if;


    IF v_fec_ult_ren IS NULL THEN
       --Entonces se utiliza la sumatoria de lo recibido
       --sino personalizo
       if v_fec_ult_per is null then
           --Se envia recibido
           v_resultado:= p_spread + p_tas_ref;
           v_es_personalizada:='N';
       else
          --Buscamos el valor personalizado
          begin
           select a.tas_utilizada
            into v_tas_utilizada
               from pr_tas_variables_det a
                 where a.nro_solicitud= p_nro_solicitud
                 and a.fec_vencimiento=v_fec_ult_per;
          exception
            when no_data_found then
              v_tas_utilizada := 0;
          end;
           --Enviamos personalizado
           v_resultado:= v_tas_utilizada;
           v_es_personalizada:='S';
       end if; 
    else
          --Traemos el valor del campo TAS_UTILIZADA
          --Sino se ajustó tiene que ser Igual a lo recibido
          IF v_fec_ult_per IS NOT NULL THEN
               --Buscamos el valor personalizado
              begin
               select a.tas_utilizada
                into v_tas_utilizada
                   from pr_tas_variables_det a
                     where a.nro_solicitud= p_nro_solicitud
                     and a.fec_vencimiento=v_fec_ult_per;
              exception
                when no_data_found then
                  v_tas_utilizada := 0;
              end;
              v_es_personalizada:='S';
          ELSE
             --No hay nada personalizado
              v_es_personalizada:='N';
              if v_tip_spread ='D' then
                v_tas_utilizada := v_val_tas_definitiva;
              else
                v_tas_utilizada := (nvl(p_spread,0) + nvl(p_tas_ref,0)) ; 
              end if;  
          END IF;
          
          v_resultado:= nvl(v_tas_utilizada,0);


    END IF;


    p_resultado:= v_resultado;
    p_personalizada:=v_es_personalizada;
EXCEPTION
    WHEN OTHERS THEN
         raise_application_error(-20000,'Obt.Tas.Interes: '|| sqlerrm);
END;



BEGIN
   --***********INICIO DE PROCESO PRINCIPAL *********************
   --Asignamos Fecha
    if P_FECHA is null then
       v_fecha:= v_fec_actual;
    else
      v_fecha:= p_fecha;
    end if;

    v_cod_tas_variable:=null;
    v_cod_tas_variable:= '222'; --222 PRESTAMOS CON TASA VARIABLE

--Para logica en donde ya existen las solicitudes
if P_NRO_SOLICITUD is not null then
   --Obtenemos los datos de la solicitud
   begin
     select a.cod_moneda, a.cod_periodo, a.fec_renegociacion, a.tip_spread,
        a.spread,a.tas_referencia,a.tas_interes
      into v_cod_moneda, v_cod_periodo , v_fec_pri_renegociacion, v_tip_spread,
         v_spr_ini, v_tas_ref_ini,v_tas_apli_ini
       from pr_tas_variables a
         where a.nro_solicitud= P_NRO_SOLICITUD
           and rownum=1;
   exception
    when no_data_found then
       v_cod_periodo:= null;
   end;

if v_cod_periodo is not null then
   --Buscamos si ya se renegoció alguna cuota
   begin
     select nvl(count(*),0)
       into v_can_renegociado
        from pr_tas_variables_det b
          where b.nro_solicitud= P_NRO_SOLICITUD
            and b.fec_renegociacion is not null
            and B.nro_cuota > 1;
   exception
     when no_data_found then
       v_can_renegociado:=0;
   end;


   v_spread:=0;
   v_tas_referencia:=0;
   v_valor:=0;

   if v_can_renegociado= 0 then
      --*** Es la primera Vez que se va a re-negociar *****
      if p_tipo = 'T' or p_tipo ='F' THEN
         --Tasa de Referencia
         LP_OBT_VAL_TAS_REFERENCIA(v_cod_moneda, v_cod_periodo, v_fecha, v_respuesta);
         if p_tipo='T' then
            V_VALOR:= nvl(v_respuesta,0);
         else
            v_tas_referencia:= nvl(v_respuesta,0);
         end if;
      end if;

      IF P_TIPO = 'S'  or p_tipo ='F' THEN
         --Spread --Para la primera re-negociación va a ser siempre el de la Sol.Inic.
         --Ya sea para tipo de spread temporal o permanente o Inicial
         LP_OBT_VAL_SPREAD(P_nro_solicitud,'D', v_fecha,v_spr_ini,
                     'S', v_devuelto);
         --Si es spread, cargamos y salimos
         if p_tipo='S' then
            V_VALOR:= nvl(v_devuelto,0);
         else
            v_spread:= nvl(v_devuelto,0);
         end if;

      end if;

      IF P_TIPO = 'F' THEN
         --Tasa de Interes Final
         -- Suma de Tasa de Referencia + Spread
          LP_OBT_TAS_INTERES_FINAL(p_nro_solicitud ,p_fecha ,v_spread,v_tas_referencia,V_VALOR, v_personalizada);
          if nvl(v_personalizada,'N')= 'N' then
               v_cod_tas_variable:='N';
            ELSE
               v_cod_tas_variable:='S';
            end if;
      END IF;
      --*** Fin de primera Vez *****
   else
      --****** Ya se negoció anteriormente   *********
        if p_tipo = 'T' or p_tipo='F' THEN
           --Tasa de Referencia
           LP_OBT_VAL_TAS_REFERENCIA(v_cod_moneda, v_cod_periodo, v_fecha, v_respuesta);
           IF p_tipo = 'T' THEN
              V_VALOR:= v_respuesta;
           ELSE
              v_tas_referencia:= nvl(v_respuesta,0);
           END IF;
        end if;


        IF p_tipo = 'S' or p_tipo='F' THEN
           if V_TIP_SPREAD= 'T' THEN
              --Si el tipo de Spread es TEMPORAL: Se utiliza el Spread inicial.
              --(De la solicitud inicial) .
               LP_OBT_VAL_SPREAD(p_nro_solicitud,'T', v_fecha,v_spr_ini,
                     'N', v_devuelto);
                V_VALOR:= v_devuelto;
           elsif V_TIP_SPREAD= 'D' THEN
              --Si el tipo de Spread es DEFINITIVO:  Se utiliza el último Spread Cargado.
              LP_OBT_VAL_SPREAD(p_nro_solicitud,'D',  v_fecha,v_spr_ini,
                      'N', v_respuesta);
              V_VALOR:= v_respuesta;
           elsif V_TIP_SPREAD= 'I' THEN
             --Sigue cargado inicial, se recalcula en forma automática
              LP_OBT_VAL_SPREAD(p_nro_solicitud,'I',  v_fecha,v_spr_ini,
                      'N', v_respuesta);
              V_VALOR:= v_respuesta;
           end if;

           IF p_tipo='F' THEN
               v_spread:= nvl(V_VALOR,0);
           END IF;
        END IF;

        IF P_TIPO = 'F' THEN
           --Tasa de Interes Final
           -- Suma de Tasa de Referencia + Spread
            V_VALOR:= nvl(v_respuesta,0) + nvl(V_SPR_INI,0);
            LP_OBT_TAS_INTERES_FINAL(p_nro_solicitud ,p_fecha ,v_spread,v_tas_referencia,V_VALOR,v_personalizada);
            if nvl(v_personalizada,'N')= 'N' then
               v_cod_tas_variable:='N';
            ELSE
               v_cod_tas_variable:='S';
            end if;
       END IF;
     --*********Fin de ya se negoció anteriormente ****

   end if;



end if;
else
  --Para logica en donde se Obtiene por cod_periodo y cod_moneda
  if p_cod_moneda is not null and p_cod_periodo is not null then
           v_cod_moneda:= p_cod_moneda;
           v_cod_periodo:= p_cod_periodo;
           --Tasa de Referencia
           IF p_tipo = 'T' THEN
              LP_OBT_VAL_TAS_REFERENCIA(v_cod_moneda, v_cod_periodo, v_fecha, v_respuesta);
              V_VALOR:= v_respuesta;
           --Spread
           ELSIF p_tipo = 'S' THEN
              LP_OBT_VAL_TAS_REFERENCIA(v_cod_moneda, v_cod_periodo, v_fecha, v_respuesta);
              if v_respuesta < p_val_ingresado then
                V_VALOR:= p_val_ingresado - v_respuesta;
              elsif v_respuesta > p_val_ingresado then
                V_VALOR:= v_respuesta- p_val_ingresado;
              else
                V_VALOR:= 0;
              end if;
          --Tasa Final
          ELSIF p_tipo = 'F' THEN
              NULL;
           END IF;


  end if;

end if;
 p_val_devuelto:= V_VALOR;
 p_cod_tasa:= v_cod_tas_variable;
exception
  when others then
     raise_application_error(-20000,'PRG_OBT_VAL_TAS_VARIABLE: '||p_nro_solicitud||' -Fec: '||P_FECHA||' -Tip0:'||P_TIPO ||' -'||sqlerrm);
END;
/

