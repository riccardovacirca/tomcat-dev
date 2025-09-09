#!/bin/bash
set -e

# ==============================================================================
# ./pg_mpi.sh -h <host> -u <user> -p <pass> -d <db_name>
# Script di test completo PostgreSQL MPI - MODALITÀ INTERATTIVA
# ==============================================================================

PG_CONTAINER=""
PG_USERNAME=""
PG_PASSWORD=""
PG_DATABASE=""

while getopts "h:u:p:d:" opt; do
  case $opt in
    h) PG_CONTAINER="$OPTARG" ;;
    u) PG_USERNAME="$OPTARG" ;;
    p) PG_PASSWORD="$OPTARG" ;;
    d) PG_DATABASE="$OPTARG" ;;
    \?) echo "Opzione non valida: -$OPTARG" >&2; exit 1 ;;
  esac
done

if [[ -z "$PG_CONTAINER" || -z "$PG_USERNAME" || -z "$PG_PASSWORD" || -z "$PG_DATABASE" ]]; then
    echo "Uso: $0 -h <container> -u <user> -p <password> -d <database>"
    exit 1
fi

# Array degli step del workflow
declare -a STEPS=(
  "1:Disinstallazione:./pg_mpi_uninstall.sh"
  "2:Installazione:./pg_mpi_install.sh"
  "3:Insert anagrafica:./pg_mpi_sql_insert_anagrafica.sh"
  "4:Insert duplicati per test:./pg_mpi_sql_insert_duplicate.sh"
  "5:Rilevamento duplicati:./pg_mpi_sql_duplicates_detect.sh"
  "6:Cerca anagrafica...:./pg_mpi_sql_search_cluster.sh"
  # Step nascosti temporaneamente
  # "7:Delete anagrafica:./pg_mpi_sql_delete_anagrafica.sh"
  # "8:Restore anagrafica:./pg_mpi_sql_restore_anagrafica.sh"
  # "9:Dashboard gestione duplicati:./pg_mpi_dashboard.sh"
  # "10:Update anagrafica:./pg_mpi_sql_update_anagrafica.sh"
)

# Funzione per mostrare il menu
show_menu() {
  local current_step=$1
  local total_steps=${#STEPS[@]}
  
  clear
  
  # Mostra step corrente compatto  
  if [[ $current_step -le $total_steps ]]; then
    local step_info=${STEPS[$((current_step-1))]}
    local step_num=$(echo $step_info | cut -d: -f1)
    local step_name=$(echo $step_info | cut -d: -f2)
    echo "Current: $step_num/$total_steps - $step_name"
    echo ""
  fi
  
  # Mostra tutti gli step come opzioni numeriche
  for i in "${!STEPS[@]}"; do
    local step_info=${STEPS[$i]}
    local step_num=$(echo $step_info | cut -d: -f1)
    local step_name=$(echo $step_info | cut -d: -f2)
    
    # Evidenzia lo step corrente
    if [[ $((i+1)) -eq $current_step ]]; then
      echo "$step_num) ▶️  $step_name (CORRENTE)"
    else
      echo "$step_num) $step_name"
    fi
  done
  
  echo ""
  echo "q) ❌ ESCI - Termina il workflow"
  echo ""
}


# Funzione per eseguire uno step
execute_step() {
  local step_number=$1
  local step_info=${STEPS[$((step_number-1))]}
  local step_num=$(echo $step_info | cut -d: -f1)
  local step_name=$(echo $step_info | cut -d: -f2)
  local step_script=$(echo $step_info | cut -d: -f3)
  
  # Determina se questo è uno step critico che richiede verbosità completa
  local is_critical_step=false
  local show_table_output=false
  
  if [[ "$step_name" == *"Disinstallazione"* ]] || [[ "$step_name" == *"Installazione"* ]]; then
    is_critical_step=true
  elif [[ "$step_name" == *"Insert duplicati"* ]] || [[ "$step_name" == *"Rilevamento duplicati"* ]] || [[ "$step_name" == *"Cerca anagrafica"* ]]; then
    show_table_output=true
  fi
  
  # Pulisci schermo per ogni step
  clear
  
  if [[ "$is_critical_step" == "true" ]]; then
    # Formato verboso per operazioni critiche
    echo "========================================"
    echo "ESECUZIONE STEP $step_num: $step_name"
    echo "========================================"
    echo "Script: $step_script"
    echo ""
  else
    # Formato compatto per operazioni standard
    echo "Step $step_num: $step_name..."
    echo ""
  fi
  
  # Verifica esistenza script
  if [[ ! -f "$step_script" ]]; then
    echo "⚠️  ERRORE: Script non trovato: $step_script"
    read -p "Premere INVIO per continuare..."
    return 1
  fi
  
  # Esegui lo script
  set +e  # Disabilita exit su errore temporaneamente
  
  if [[ "$is_critical_step" == "true" ]]; then
    # Mostra tutto l'output per operazioni critiche
    "$step_script" -h "$PG_CONTAINER" -u "$PG_USERNAME" -p "$PG_PASSWORD" -d "$PG_DATABASE"
  elif [[ "$show_table_output" == "true" ]]; then
    # Mostra sempre l'output completo per step che devono mostrare tabelle
    "$step_script" -h "$PG_CONTAINER" -u "$PG_USERNAME" -p "$PG_PASSWORD" -d "$PG_DATABASE"
  else
    # Cattura output e mostra risultato per operazioni standard
    local output
    output=$("$step_script" -h "$PG_CONTAINER" -u "$PG_USERNAME" -p "$PG_PASSWORD" -d "$PG_DATABASE" 2>&1)
    
    # Mostra risultato dell'operazione
    # Controlla se ci sono errori reali (non solo la parola "errori" nel contesto)
    if echo "$output" | grep -qi "error:\|errore:\|failed\|fallito\|exit.*[1-9]"; then
      echo "❌ Errore durante l'esecuzione:"
      echo "$output" | grep -i "error:\|errore:\|failed\|fallito" | head -5
    else
      # Mostra output significativo o messaggio generico
      if [[ -n "$output" ]] && [[ $(echo "$output" | wc -l) -le 10 ]]; then
        echo "$output"
      else
        echo "✅ Operazione eseguita"
      fi
    fi
  fi
  
  local exit_code=$?
  set -e  # Riabilita exit su errore
  
  # Sempre mostra prompt per tornare al menu
  echo ""
  if [[ $exit_code -ne 0 ]]; then
    echo "❌ Step completato con errori (exit code: $exit_code)"
  fi
  
  read -p "Premere INVIO per tornare al menu..."
  
  return 0
}


# Loop principale
main_loop() {
  local current_step=1
  local total_steps=${#STEPS[@]}
  
  while true; do
    show_menu $current_step
    
    read -p "Scelta [1-$total_steps/q]: " choice
    
    case $choice in
      [1-9]|1[0-1])
        # Verifica che sia un numero valido
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le $total_steps ]]; then
          execute_step "$choice"
          
          # Aggiorna current_step al prossimo step dopo quello eseguito
          if [[ "$choice" -eq $total_steps ]]; then
            # Se abbiamo eseguito l'ultimo step
            current_step=$total_steps
          else
            # Aggiorna al prossimo step per il suggerimento visivo
            current_step=$((choice + 1))
          fi
        else
          echo "Step non valido: $choice"
          read -p "Premere INVIO per continuare..."
        fi
        ;;
      q|Q)
        echo ""
        echo "Uscita dal workflow MPI."
        exit 0
        ;;
      *)
        echo "Scelta non valida: $choice"
        echo "Inserisci un numero da 1 a $total_steps o 'q' per uscire."
        read -p "Premere INVIO per continuare..."
        ;;
    esac
  done
}

# Avvio del workflow interattivo
echo "Avvio PostgreSQL MPI Workflow Interattivo..."
main_loop