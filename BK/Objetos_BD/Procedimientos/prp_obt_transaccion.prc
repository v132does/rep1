CREATE OR REPLACE PROCEDURE IT.PRP_OBT_TRANSACCION
 (P_CONCEPTO IN PR_COB_PRIORIDADES.CONCEPTO%TYPE
 ,P_ESTADO IN PR_CTA_PRESTAMOS.ESTADO%TYPE
 ,P_TIPO IN PR_CTA_PRESTAMOS.TIPO%TYPE
 ,P_TIP_INTERES IN PR_CTA_PRESTAMOS.TIP_INTERES%TYPE
 ,P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE
 ,P_COD_ORI_FONDO IN PR_CTA_PRESTAMOS.COD_ORI_FONDO%TYPE
 ,P_EST_NUEVO IN PR_CTA_PRESTAMOS.ESTADO%TYPE
 ,P_OPERACION IN VARCHAR2 DEFAULT 'C'
 ,P_COD_TRANSACCION OUT GE_TRANSACCIONES.COD_TRANSACCION%TYPE  -- OUT
 ,P_DESCRIPCION OUT GE_MOVIMIENTOS.CONCEPTO%TYPE               -- OUT
 )
 IS
v_cod_ori_fondo pr_cta_prestamos.cod_ori_fondo%type;
v_por_ori_fondo pr_cta_prestamos.por_ori_fondo%type;
v_cod_moneda pr_cta_prestamos.cod_moneda%type;
v_fon_propio varchar2(1):= 'N';
/* proceso que retorna la transacción y el concepto para el movimiento, que se deben usar por cobro o cambio de situación,
   teniendo en cuenta las condiciones del préstamo
P_OPERACION -> C cobro / E cambio de situación o estado
P_TIPO      -> P plazo fijo / D descuento documento / A amortizable
P_TIP_INTERES -> A adelantado / V vencido */

v_cod_modalidad pr_cta_prestamos.cod_modalidad%type; --DYDMR-9438

BEGIN
   -- sólo por la porción de capital debe considerar origen de fondos
   if p_concepto = 'CA' then   --- Capital
      select cod_ori_fondo, por_ori_fondo, cod_moneda, cod_modalidad
        into v_cod_ori_fondo, v_por_ori_fondo, v_cod_moneda, v_cod_modalidad
        from pr_cta_prestamos
       where nro_cuenta = p_nro_cuenta;

      --ver si es fondos propios u otro
      if p_cod_ori_fondo = fug_obt_pardinamico('COD_ORI_FON_DESEMB',NULL,NULL,v_cod_moneda,null,null) or
         p_cod_ori_fondo = fug_obt_pardinamico('COD_ORI_FON_DESEMB',6,v_cod_modalidad,v_cod_moneda,null,null) then--ver si es fondo propio 7 - DYDMR-9438
         --es fondos propios
         v_fon_propio := 'S';
      end if;
   end if;

   -- para Cobros
   if p_operacion = 'C' then
     -- determinar transacción de acuerdo a las condiciones
     if p_concepto = 'CA' then   --- Capital
        if p_estado in ('C','A') then  --- Cuota Vigente o Vigente atrasada
           if p_tipo <> 'P' then   --- Amortizable
              p_cod_transaccion := 801;    --- Fondos Propios
              if v_fon_propio = 'N' then
                 p_cod_transaccion := 965; ---AFD
              end if;
           else
              p_cod_transaccion := 805;    --- Fondos Propios
              if v_fon_propio = 'N' then
                 p_cod_transaccion := 966; ---AFD
              end if;
           end if;
        end if;
        if p_estado in ('V') then --- Cuota Vencida
           if p_tipo <> 'P' then  --- Amortizable
              p_cod_transaccion := 820;    --- Fondos Propios
              if v_fon_propio = 'N' then
                 p_cod_transaccion := 967; ---AFD
              end if;
           else
              p_cod_transaccion := 821;    --- Fondos Propios
              if v_fon_propio = 'N' then
                 p_cod_transaccion := 968; ---AFD
              end if;
           end if;
        end if;
        if p_estado in ('G') then --- Cuota En Gestion
           p_cod_transaccion := 822;    --- Fondos Propios
           if v_fon_propio = 'N' then
              p_cod_transaccion := 969; ---AFD
           end if;
        end if;
        if p_estado in ('M','I') then --- Cuota Morosa o Irrecuperable
           p_cod_transaccion := 823;    --- Fondos Propios
           if v_fon_propio = 'N' then
              p_cod_transaccion := 970; ---AFD
           end if;
        end if;
     end if;

     if p_concepto in ('IA','IN') then   --- Interes o Interes Adelantado
        if p_estado in ('C','A') then
           if p_tip_interes = 'A' and p_concepto = 'IA' then
              p_cod_transaccion := 806;
           elsif p_concepto = 'IN' then
              p_cod_transaccion := 802;
           end if;
        end if;
        if p_estado = 'V' then
           if p_tip_interes = 'A' and p_concepto = 'IA' then
              p_cod_transaccion := 814;
           elsif p_concepto = 'IN' then
              p_cod_transaccion := 817;
           end if;
        end if;
        if p_estado = 'G' then
           if p_tip_interes = 'A' and p_concepto = 'IA' then
              p_cod_transaccion := 818;
           elsif p_concepto = 'IN' then
              p_cod_transaccion := 825;
           end if;
        end if;
        if p_estado in ('M','I') then
           if p_tip_interes = 'A' and p_concepto = 'IA' then
              p_cod_transaccion := 826;
           elsif p_concepto = 'IN' then
              p_cod_transaccion := 828;
           end if;
        end if;
     end if;
     if p_concepto = 'MO' then  --- Mora sobre capital
        if p_estado in ('C','A') then
           if p_tip_interes = 'A' then
              p_cod_transaccion := 810;
           else
              if p_tipo = 'P' then
                 p_cod_transaccion := 807;
              else
                 p_cod_transaccion := 813;
              end if;
           end if;
        end if;
        if p_estado = 'V' then
           p_cod_transaccion := 815;
        end if;
        if p_estado = 'G' then
           p_cod_transaccion := 819;
        end if;
        if p_estado IN ('M','I') then
           p_cod_transaccion := 827;
        end if;
     end if;
     if p_concepto = 'MI' then   --- Mora sobre interes
        if p_estado in ('C','A') then --- Vigente o Vigente vencida
           if p_tipo = 'P' then
              p_cod_transaccion := 835;
           else
              p_cod_transaccion := 836;
           end if;
        elsif p_estado = 'V' then
           p_cod_transaccion    := 837;
        elsif p_estado = 'G' then
           p_cod_transaccion    := 838;
        elsif p_estado IN ('M','I') then
           p_cod_transaccion    := 839;
        end if;
     end if;
     if p_concepto = 'MA' then --- Mora sobre interes adelantado
        if p_estado in ('C','A') then --- Vigente o Vigente vencida
           if p_tipo = 'P' then
              p_cod_transaccion := 830;
           else
              p_cod_transaccion := 831;
           end if;
        elsif p_estado = 'V' then
           p_cod_transaccion    := 832;
        elsif p_estado = 'G' then
           p_cod_transaccion    := 833;
        elsif p_estado IN ('M','I') then
           p_cod_transaccion    := 834;
        end if;
     end if;
     if p_concepto = 'PU' then --- Punitorio
        p_cod_transaccion    := 849;
     end if;
     if p_concepto = 'IM' then --- Impuestos
        p_cod_transaccion    := 709;
     end if;
     if p_concepto = 'CG' then --- Cargos
        p_cod_transaccion    := 712;
     end if;
   end if; -- hasta acá el cobro

   -- para Cambio de Situación (Estado)
   if p_operacion <> 'C' then
     -- sólo por la porción de saldo capital debe considerar origen de fondos
     IF p_estado IN ('C','A')  AND p_est_nuevo IN ('V','G','M','I') THEN
        -- transf. de VIGENTE A VENCIDA O GESTION O MOROSA ---

        IF p_tipo in ('P','D') THEN          /* PLAZO FIJO o descuento */
           IF p_est_nuevo = 'V' THEN
              p_cod_transaccion := 920;
              p_descripcion    := 'TRANSF.CAP.VIG.A VENC-PF';
              if v_fon_propio = 'N' then
                 p_cod_transaccion := 971; ---AFD
              end if;
           ELSIF p_est_nuevo = 'G' THEN
              p_cod_transaccion := 933;
              p_descripcion   := 'TRANSF.CAP.VIG.A GEST-PF';
              if v_fon_propio = 'N' then
                 p_cod_transaccion := 973; ---AFD
              end if;
           ELSIF p_est_nuevo IN ('M','I') THEN
              p_cod_transaccion := 936;
              p_descripcion    := 'TRANSF.CAP.VIG.A MORO-PF';
              if v_fon_propio = 'N' then
                 p_cod_transaccion := 975; ---AFD
              end if;
           END IF;
        ELSIF p_tipo = 'A' THEN             /* amortizable */
           IF p_est_nuevo = 'V' THEN
              p_cod_transaccion := 932;
              p_descripcion    := 'TRANSF.CAP.VIG.A VENC-AM';
              if v_fon_propio = 'N' then
                 p_cod_transaccion := 972; ---AFD
              end if;
           ELSIF p_est_nuevo = 'G' THEN
              p_cod_transaccion := 934;
              p_descripcion    := 'TRANSF.CAP.VIG.A GEST-AM';
              if v_fon_propio = 'N' then
                 p_cod_transaccion := 974; ---AFD
              end if;
           ELSIF p_est_nuevo IN ('M','I') THEN
              p_cod_transaccion := 937;
              p_descripcion    := 'TRANSF.CAP.VIG.A MORA-AM';
              if v_fon_propio = 'N' then
                 p_cod_transaccion := 976; ---AFD
              end if;
           END IF;
        END IF;
     END IF;
     IF p_estado = 'V' AND  p_est_nuevo = 'G' THEN       -- De VENCIDA a EN GESTION
        p_cod_transaccion := 926;
        p_descripcion    := 'TRANSF.CAPITAL VENC. A EN GEST.';
        if v_fon_propio = 'N' then
           p_cod_transaccion := 977; ---AFD
        end if;
     END IF;
     IF p_estado = 'V' AND  p_est_nuevo IN ('M','I') THEN  -- De VENCIDA a MOROSA
        p_cod_transaccion := 939;
        p_descripcion    := 'TRANSF.CAPITAL VENC. A MOROSA';
        if v_fon_propio = 'N' then
           p_cod_transaccion := 978; ---AFD
        end if;
     END IF;
     IF p_estado = 'G' AND  p_est_nuevo IN ('M','I') THEN -- De EN GESTION A MOROSA
        p_cod_transaccion := 929;
        p_descripcion    := 'TRANSF.CAPITAL EN GEST. A MOROSA';
        if v_fon_propio = 'N' then
           p_cod_transaccion := 979; ---AFD
        end if;
     END IF;

     /* esto solo se hace si hay traslado para atras */
     IF p_estado IN ('V','G','M','I') AND p_est_nuevo IN ('A','C') THEN
        -- transf. de VENCIDA O GESTION O MOROSA a CARTERA VIGENTE ---

        IF p_tipo in ('P', 'D') THEN
           IF p_estado = 'V' THEN
              p_cod_transaccion := 920;
              p_descripcion    := 'TRANSF.CAP.VENC.A VIG.-PF';
              if v_fon_propio = 'N' then
                 p_cod_transaccion := 971; ---AFD
              end if;
           ELSIF p_estado = 'G' THEN
              p_cod_transaccion := 933;
              p_descripcion    := 'TRANSF.CAP.GEST.A VIG.-PF';
              if v_fon_propio = 'N' then
                 p_cod_transaccion := 973; ---AFD
              end if;
           ELSIF p_estado IN ('M','I') THEN
              p_cod_transaccion := 936;
              p_descripcion    := 'TRANSF.CAP.MORO.A VIG.-PF';
              if v_fon_propio = 'N' then
                 p_cod_transaccion := 975; ---AFD
              end if;
           END IF;
        ELSIF p_tipo = 'A' THEN
           IF p_estado = 'V' THEN
              p_cod_transaccion := 932;
              p_descripcion    := 'TRANSF.CAP.VENC.A VIG-AM';
              if v_fon_propio = 'N' then
                 p_cod_transaccion := 972; ---AFD
              end if;
           ELSIF p_estado = 'G' THEN
              p_cod_transaccion := 934;
              p_descripcion    := 'TRANSF.CAP.GEST.A VIG-AM';
              if v_fon_propio = 'N' then
                 p_cod_transaccion := 974; ---AFD
              end if;
           ELSIF p_estado IN ('M','I') THEN
              p_cod_transaccion := 937;
              p_descripcion    := 'TRANSF.CAP.MORA A VIG-AM';
              if v_fon_propio = 'N' then
                 p_cod_transaccion := 976; ---AFD
              end if;
           END IF;
        END IF;
     END IF;
     IF p_estado = 'G' AND  p_est_nuevo = 'V' THEN -- De GESTION A VENCIDA
        p_cod_transaccion := 926;
        p_descripcion    := 'TRANSF.CAPITAL DE GEST a VENC.';
        if v_fon_propio = 'N' then
           p_cod_transaccion := 977; ---AFD
        end if;
     END IF;
     IF p_estado IN ('M','I') AND p_est_nuevo = 'V' THEN  -- De MOROSA A VENCIDA
        p_cod_transaccion := 939;
        p_descripcion    := 'TRANSF.CAPITAL DE MOROSA A VENC';
        if v_fon_propio = 'N' then
           p_cod_transaccion := 978; ---AFD
        end if;
     END IF;
     IF p_estado IN ('M','I') AND p_est_nuevo = 'G' THEN -- De MOROSA A GESTION
        p_cod_transaccion := 929;
        p_descripcion    := 'TRANSF.CAPITAL DE MOROSA A GESTION';
        if v_fon_propio = 'N' then
           p_cod_transaccion := 979; ---AFD
        end if;
     END IF;
   end if; -- hasta acá cambio de situación

   --- Para que de error de transacción si no recupera nada
   IF p_cod_transaccion is null then
     if p_estado = 'X' then --Si la cuota está pendiente de verificación
       raise_application_error(-20000,'Cuenta '||P_NRO_CUENTA||' con cuota pendiente de Verificacion. Estado. '||P_ESTADO);
     else
       p_cod_transaccion := -1;
      end if;
   end if;

exception
  when others then
    if p_cod_transaccion is null and p_estado = 'X' then --Si la transaccion es nula y la cuota está pendiente de verificación
      raise_application_error(-20001,'Cuenta '||P_NRO_CUENTA||' con cuota Pendiente de Autorizacion. Estado. '||P_ESTADO);
    else
      raise_application_error(-20000,'Obt.Trans. Cta.'||P_NRO_CUENTA||' Est.'||P_ESTADO||' Tipo '||P_TIPO||' Int.'||P_TIP_INTERES
                                    ||' Ori.Fondo '||P_COD_ORI_FONDO||'-'||sqlerrm);
    end if;
END;
/

