create or replace procedure it.PRG_CTL_DAT_11G is
  v_contador   varchar2(100);
  v_cantidad    varchar2(100);
  v_tabla       varchar2(100);
  v_campo       varchar2(100);
  v_db_actual   varchar2(100);
  v_db_anterior varchar2(100);
  v_diferencias varchar2(1) := 'N';
  CURSOR TABLAS IS
         Select distinct(a.nom_tabla) tabla, a.totalizador
           From mi_11g_controles a
          Order by 1,2;  
  
  CURSOR CAMPOS (P_TABLA IN VARCHAR2) IS
         Select a.nom_campo campo
           From mi_11g_controles a
          where a.nom_tabla   = P_TABLA
            and a.totalizador = 'S';
           
  FUNCTION F_CONTADOR ( P_TABLA IN VARCHAR2 
                       ,P_CAMPO IN VARCHAR2 
                       ,P_TIPO  IN VARCHAR2
                       ,P_BASE  IN VARCHAR2
                       ) RETURN VARCHAR2 IS
                        
    TYPE t_tipo_cursor IS REF CURSOR;
       c_cursor    t_tipo_cursor;
       v_sentencia varchar2(2000);
       v_base      varchar2(4) := NULL;
       v_tipo      varchar2(200);
    BEGIN
       IF P_BASE = 'P' THEN
          v_base := '@SUN'; 
       END IF;
       
       If    p_tipo = 'T' Then --> Totalizador de Registros por Tablas
          v_tipo := 'count(*)';
       Elsif p_tipo = 'S' Then --> Sumador de Campos por Tablas
          v_tipo := 'sum('||P_CAMPO||')';
       End If;
       
       v_sentencia := 'Select '||v_tipo||' from '||P_TABLA||V_BASE;
       
       open c_cursor for v_sentencia ;
       loop
          fetch c_cursor into v_cantidad;
          exit when c_cursor%notfound;
       end loop;
       close c_cursor;
       if v_cantidad is null then
          return '0';
       else
          return v_cantidad;
       end if;
    END;
 

begin
    update mi_11g_controles a 
       set a.db_actual   = null, 
           a.db_anterior = null, 
           a.diferencia  = null, 
           a.correcto    = null;
    For i in tablas loop
        v_tabla       := i.tabla;
        v_contador    := 0;
        v_db_actual   := null;
        v_db_anterior := null;
        v_diferencias := 'N';
        If i.totalizador = 'S' Then
            For x in campos(i.tabla) loop
                v_campo       := x.campo;
                v_db_actual   := f_contador (i.tabla,x.campo,'S','P');
                v_db_anterior := f_contador (i.tabla,x.campo,'S','X');
                v_contador   := v_db_actual - v_db_anterior;
                if v_contador < 0 then
                   v_contador := v_contador * -1;
                End if;
                If v_contador != 0 then
                   v_diferencias := 'S';
                   update mi_11g_controles a 
                      set a.correcto    = 'N'          ,
                          a.db_actual   = v_db_actual  ,
                          a.db_anterior = v_db_anterior,
                          a.diferencia  = v_contador 
                    where a.nom_tabla   = i.tabla 
                      and a.nom_campo   = x.campo;
                Else 
                   update mi_11g_controles a 
                      set a.correcto    = 'S'          ,
                          a.db_actual   = v_db_actual  ,
                          a.db_anterior = v_db_anterior,
                          a.diferencia  = v_contador 
                    where a.nom_tabla   = i.tabla 
                      and a.nom_campo   = x.campo;
                End If;
            End Loop;
        Else
            v_db_actual   := f_contador (i.tabla,Null,'T','P');
            v_db_anterior := f_contador (i.tabla,Null,'T','X');
            v_contador    := v_db_actual - v_db_anterior;
            if v_contador < 0 then
               v_contador := v_contador * -1;
            End if;
            If v_contador != 0 or v_diferencias = 'S' then
               update mi_11g_controles a 
                  set a.correcto    = 'N'          ,
                      a.db_actual   = v_db_actual  ,
                      a.db_anterior = v_db_anterior,
                      a.diferencia  = v_contador
                where a.nom_tabla   = i.tabla
                  and a.nom_campo   = 'CANTIDAD';
            Else 
               update mi_11g_controles a 
                  set a.correcto    = 'S'          ,
                      a.db_actual   = v_db_actual  ,
                      a.db_anterior = v_db_anterior,
                      a.diferencia  = v_contador 
                 where a.nom_tabla  = i.tabla
                   and a.nom_campo  = 'CANTIDAD';
            End If;
         End If;
    End Loop;
EXCEPTION
    When Others then
         raise_application_error(-20000,'Error al procesar datos de: '||v_tabla||'.'||v_campo||' - '||sqlerrm);
END;
/

